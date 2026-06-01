import Foundation
import SwiftData
import ZIPFoundation

@MainActor
@Observable
final class HistoryImporter {
    var total: Int = 0
    var processed: Int = 0
    var imported: Int = 0
    var skipped: Int = 0
    var failed: Int = 0
    var isRunning: Bool = false
    var cancelRequested: Bool = false

    // Test-only: trigger cancellation after N imported activities. Ignored when nil.
    var cancelAfter: Int?

    private static let batchSize = 100

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func cancel() { cancelRequested = true }

    func importHistory(from zipURL: URL, yearsBack: Int? = nil) async throws {
        isRunning = true
        defer { isRunning = false }

        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .read)
        } catch {
            throw ImportError.invalidArchive
        }

        // Pre-scan central directory only (no decompression).
        let cutoff = yearsBack.map { Self.cutoffYear(yearsBack: $0) }
        let matching: [Entry] = archive.compactMap { entry in
            let name = (entry.path as NSString).lastPathComponent
            guard name.hasPrefix("training-session-"), name.hasSuffix(".json") else { return nil }
            if let cutoff, let year = Self.year(fromTrainingFileName: name), year < cutoff {
                return nil
            }
            return entry
        }
        guard !matching.isEmpty else { throw ImportError.wrongFormat }
        total = matching.count

        var seenMinutes: Set<Date> = try {
            var descriptor = FetchDescriptor<Activity>()
            descriptor.propertiesToFetch = [\.startTime]
            let all = try context.fetch(descriptor)
            return Set(all.map { Self.minuteBucket($0.startTime) })
        }()

        let decoder = JSONDecoder()
        var batchCount = 0
        for entry in matching {
            defer { processed += 1 }
            if cancelRequested { break }

            let activity: Activity
            do {
                let data = try await Self.extractEntry(entry, from: archive)
                let session = try decoder.decode(GDPRTrainingSession.self, from: data)
                let fileID = (entry.path as NSString).lastPathComponent
                    .replacingOccurrences(of: ".json", with: "")
                guard let a = session.toActivity(fileID: fileID) else {
                    failed += 1; continue
                }
                activity = a
            } catch {
                failed += 1; continue
            }

            let bucket = Self.minuteBucket(activity.startTime)
            if seenMinutes.contains(bucket) {
                skipped += 1; continue
            }
            seenMinutes.insert(bucket)
            context.insert(activity)
            imported += 1
            batchCount += 1

            if batchCount >= Self.batchSize {
                try saveBatch(batchCount: &batchCount)
            }
            if let limit = cancelAfter, imported >= limit {
                cancelRequested = true
            }
        }
        try saveBatch(batchCount: &batchCount)
        if cancelRequested { throw ImportError.cancelled }
    }

    // Save pending inserts; on failure, reconcile the imported counter so
    // it reflects what actually landed on disk.
    private func saveBatch(batchCount: inout Int) throws {
        do {
            try context.save()
            batchCount = 0
        } catch {
            imported -= batchCount
            batchCount = 0
            throw ImportError.ioFailure(error)
        }
    }

    // Extract a single entry off-main. Returns the decompressed bytes.
    private static func extractEntry(_ entry: Entry, from archive: Archive) async throws -> Data {
        try await Task.detached(priority: .utility) {
            var buf = Data()
            _ = try archive.extract(entry) { chunk in buf.append(chunk) }
            return buf
        }.value
    }

    // Helpers
    static func year(fromTrainingFileName name: String) -> Int? {
        let prefix = "training-session-"
        guard name.hasPrefix(prefix), name.count >= prefix.count + 4 else { return nil }
        return Int(name.dropFirst(prefix.count).prefix(4))
    }

    static func cutoffYear(yearsBack: Int) -> Int {
        Calendar(identifier: .gregorian).component(.year, from: Date()) - yearsBack
    }

    static func minuteBucket(_ date: Date) -> Date {
        ActivityRepository.minuteBucket(date)
    }
}
