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
}
