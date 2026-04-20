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
        mockAccessLink.stubbedActivities = [makeActivity(id: "a1"), makeActivity(id: "a2")]

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
        try repo.save(makeActivity(id: "existing"))
        mockAccessLink.stubbedActivities = [makeActivity(id: "existing"), makeActivity(id: "new")]

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

    func registerUser() async throws -> String { "user-1" }
    func pullNewActivities() async throws -> [Activity] {
        if let e = pullError { throw e }
        return stubbedActivities
    }
}
