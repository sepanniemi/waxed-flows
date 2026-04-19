import XCTest
import SwiftData
@testable import PolarMyFlow

@MainActor
final class HistoryImporterTests: XCTestCase {
    var context: ModelContext!
    var repo: ActivityRepository!

    override func setUpWithError() throws {
        context = try makeTestContext()
        repo = ActivityRepository(context: context)
    }

    func test_import_validZip_insertsActivities() async throws {
        let zipURL = try ZipFixture.make([
            "training-session-2025-01-15-aaa.json":
                ZipFixture.session(startTime: "2025-01-15T09:00:00.000"),
            "training-session-2025-02-10-bbb.json":
                ZipFixture.session(startTime: "2025-02-10T07:30:00.000"),
        ])
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let importer = HistoryImporter(context: context)
        try await importer.importHistory(from: zipURL)

        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(importer.imported, 2)
        XCTAssertEqual(importer.failed, 0)
    }

    func test_import_skipsActivityIfMinutePrecisionStartTimeExists() async throws {
        // Pre-populate DB with an activity at 2025-01-15 09:00:23 — should collide
        // with the imported one that starts at 09:00:00 (same minute).
        let cal = Calendar(identifier: .gregorian)
        let preExisting = cal.date(from: DateComponents(
            year: 2025, month: 1, day: 15, hour: 9, minute: 0, second: 23
        ))!
        try repo.save(makeActivity(id: "pre-existing", startTime: preExisting))

        let zipURL = try ZipFixture.make([
            "training-session-2025-01-15-aaa.json":
                ZipFixture.session(startTime: "2025-01-15T09:00:00.000"),
            "training-session-2025-02-10-bbb.json":
                ZipFixture.session(startTime: "2025-02-10T07:30:00.000"),
        ])
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let importer = HistoryImporter(context: context)
        try await importer.importHistory(from: zipURL)

        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains { $0.id == "pre-existing" })
        XCTAssertEqual(importer.imported, 1)
        XCTAssertEqual(importer.skipped, 1)
    }

    func test_import_cancelMidStream_commitsPartialProgress() async throws {
        // Build a zip with 250 sessions so we're guaranteed to cross a batch boundary.
        var entries: [String: Data] = [:]
        for i in 0..<250 {
            let minute = String(format: "%02d", i % 60)
            let hour = String(format: "%02d", (i / 60) % 24)
            let day = String(format: "%02d", max(1, (i / (60*24)) + 1))
            let start = "2025-06-\(day)T\(hour):\(minute):00.000"
            entries["training-session-2025-06-\(day)-\(i).json"] =
                ZipFixture.session(startTime: start)
        }
        let zipURL = try ZipFixture.make(entries)
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let importer = HistoryImporter(context: context)
        importer.cancelAfter = 100   // test-only hook

        do {
            try await importer.importHistory(from: zipURL)
            XCTFail("expected cancellation to throw")
        } catch ImportError.cancelled {
            // expected
        }

        let all = try repo.fetchAll()
        XCTAssertGreaterThanOrEqual(all.count, 100)  // at least one batch persisted
        XCTAssertLessThan(all.count, 250)            // but not all
    }

    func test_import_invalidZip_throwsInvalidArchive() async throws {
        let bogus = FileManager.default.temporaryDirectory
            .appendingPathComponent("bogus-\(UUID().uuidString).zip")
        try Data("not a zip".utf8).write(to: bogus)
        defer { try? FileManager.default.removeItem(at: bogus) }

        let importer = HistoryImporter(context: context)
        do {
            try await importer.importHistory(from: bogus)
            XCTFail("expected throw")
        } catch ImportError.invalidArchive {
            // expected
        }
    }

    func test_import_zipWithNoSessionFiles_throwsWrongFormat() async throws {
        let zipURL = try ZipFixture.make([
            "readme.txt": Data("hello".utf8),
            "physical-information.json": Data("{}".utf8),
        ])
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let importer = HistoryImporter(context: context)
        do {
            try await importer.importHistory(from: zipURL)
            XCTFail("expected throw")
        } catch ImportError.wrongFormat {
            // expected
        }
    }

    func test_import_malformedSessionCountedAsFailed_restContinue() async throws {
        let zipURL = try ZipFixture.make([
            "training-session-2025-01-15-aaa.json":
                ZipFixture.session(startTime: "2025-01-15T09:00:00.000"),
            "training-session-2025-01-16-bbb.json":
                Data("{ not valid json".utf8),
            "training-session-2025-02-10-ccc.json":
                ZipFixture.session(startTime: "2025-02-10T07:30:00.000"),
        ])
        defer { try? FileManager.default.removeItem(at: zipURL.deletingLastPathComponent()) }

        let importer = HistoryImporter(context: context)
        try await importer.importHistory(from: zipURL)

        XCTAssertEqual(importer.imported, 2)
        XCTAssertEqual(importer.failed, 1)
    }
}
