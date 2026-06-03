import XCTest
import SwiftData
@testable import PolarMyFlow

final class SyncCoordinatorTests: XCTestCase {
    var context: ModelContext!
    var repo: ActivityRepository!
    var coordinator: SyncCoordinator!
    var mockAccessLink: MockAccessLinkClient!

    override func setUpWithError() throws {
        context = try makeTestContext()
        repo = ActivityRepository(context: context)
        mockAccessLink = MockAccessLinkClient()
        coordinator = SyncCoordinator(repository: repo, accessLinkClient: mockAccessLink)
    }

    func test_sync_savesReturnedActivities() async throws {
        // Distinct minutes so the minute-bucket dedup keeps them separate.
        mockAccessLink.stubbedActivities = [
            makeActivity(id: "a1", startTime: Date(timeIntervalSince1970: 1_700_000_000)),
            makeActivity(id: "a2", startTime: Date(timeIntervalSince1970: 1_700_000_120)),
        ]

        let imported = try await coordinator.sync(userID: "user-1")

        XCTAssertEqual(imported, 2)
        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 2)
    }

    func test_sync_emptyResponse_importsZero() async throws {
        mockAccessLink.stubbedActivities = []

        let imported = try await coordinator.sync(userID: "user-1")

        XCTAssertEqual(imported, 0)
    }

    func test_sync_deduplication_doesNotDoubleCount() async throws {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        try repo.save(makeActivity(id: "existing", startTime: t0))
        // "existing" repeats (same id → deduped); "new" is a distinct minute → added.
        mockAccessLink.stubbedActivities = [
            makeActivity(id: "existing", startTime: t0),
            makeActivity(id: "new", startTime: Date(timeIntervalSince1970: 1_700_000_120)),
        ]

        _ = try await coordinator.sync(userID: "user-1")

        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 2)
    }

    func test_sync_updatesLastSyncedAt() async throws {
        mockAccessLink.stubbedActivities = []
        let before = Date()

        _ = try await coordinator.sync(userID: "user-1")

        let state = try repo.syncState(forUserID: "user-1")
        XCTAssertNotNil(state.lastSyncedAt)
        XCTAssertGreaterThanOrEqual(state.lastSyncedAt!, before)
    }

    func test_sync_passesSinceToClient() async throws {
        _ = try await coordinator.sync(userID: "user-1")      // first sync — sets lastSyncedAt
        mockAccessLink.stubbedActivities = []
        _ = try await coordinator.sync(userID: "user-1")      // second sync — should pass since
        XCTAssertNotNil(mockAccessLink.capturedSince)
    }

    func test_sync_propagatesAccessLinkErrors() async throws {
        mockAccessLink.pullError = NSError(domain: "test", code: 1)

        do {
            _ = try await coordinator.sync(userID: "user-1")
            XCTFail("expected sync to throw")
        } catch {
            // expected
        }
    }
}

// MARK: - Mock

class MockAccessLinkClient: AccessLinkClientProtocol {
    var stubbedActivities: [Activity] = []
    var pullError: Error?
    var capturedSince: Date?

    func registerUser() async throws -> String { "user-1" }
    func pullNewActivities(since: Date?) async throws -> [Activity] {
        capturedSince = since
        if let e = pullError { throw e }
        return stubbedActivities
    }
}
