import XCTest
import SwiftData
@testable import PolarMyFlow

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
}
