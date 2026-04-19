import Foundation
import SwiftData
import ZIPFoundation

@Observable
final class HistoryImporter {
    var total: Int = 0
    var processed: Int = 0
    var imported: Int = 0
    var skipped: Int = 0
    var failed: Int = 0
    var isRunning: Bool = false
    var cancelRequested: Bool = false

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func cancel() { cancelRequested = true }

    func importHistory(from zipURL: URL) async throws {
        isRunning = true
        defer { isRunning = false }

        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("polar-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        do {
            try FileManager.default.unzipItem(at: zipURL, to: workDir)
        } catch {
            throw ImportError.invalidArchive
        }

        let sessionFiles = try enumerateSessionFiles(in: workDir)
        guard !sessionFiles.isEmpty else { throw ImportError.wrongFormat }

        total = sessionFiles.count

        let existingMinutes: Set<Date> = try {
            let descriptor = FetchDescriptor<Activity>()
            let all = try context.fetch(descriptor)
            return Set(all.map { Self.minuteBucket($0.startTime) })
        }()
        var seenMinutes = existingMinutes

        for fileURL in sessionFiles {
            defer { processed += 1 }
            guard !cancelRequested else { throw ImportError.cancelled }
            do {
                let data = try Data(contentsOf: fileURL)
                let session = try JSONDecoder().decode(GDPRTrainingSession.self, from: data)
                let fileID = fileURL.deletingPathExtension().lastPathComponent
                guard let activity = session.toActivity(fileID: fileID) else {
                    failed += 1
                    continue
                }
                let bucket = Self.minuteBucket(activity.startTime)
                if seenMinutes.contains(bucket) {
                    skipped += 1
                    continue
                }
                seenMinutes.insert(bucket)
                context.insert(activity)
                imported += 1
            } catch {
                failed += 1
            }
        }
        try context.save()
    }

    static func minuteBucket(_ date: Date) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return cal.date(from: comps) ?? date
    }

    private func enumerateSessionFiles(in dir: URL) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var results: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            let name = url.lastPathComponent
            if name.hasPrefix("training-session-") && name.hasSuffix(".json") {
                results.append(url)
            }
        }
        return results
    }
}
