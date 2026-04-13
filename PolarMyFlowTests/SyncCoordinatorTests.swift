import XCTest
import SwiftData
@testable import PolarMyFlow

final class SyncCoordinatorTests: XCTestCase {
    var context: ModelContext!
    var repo: ActivityRepository!
    var coordinator: SyncCoordinator!
    var mockAccessLink: MockAccessLinkClient!
    var mockFlowWeb: MockFlowWebClient!

    override func setUpWithError() throws {
        context = try makeTestContext()
        repo = ActivityRepository(context: context)
        mockAccessLink = MockAccessLinkClient()
        mockFlowWeb = MockFlowWebClient()
        coordinator = SyncCoordinator(
            repository: repo,
            accessLinkClient: mockAccessLink,
            flowWebClient: mockFlowWeb
        )
    }

    func test_firstLaunch_runsHistoricalImportThenRegistersAccessLink() async throws {
        mockFlowWeb.stubbedActivities = [makeActivity(id: "hist-1")]
        mockAccessLink.stubbedUserID = "user-42"
        mockAccessLink.stubbedActivities = []

        let progress = try await coordinator.sync(userID: "user-42")

        XCTAssertTrue(mockFlowWeb.fetchAllCalled)
        XCTAssertTrue(mockAccessLink.registerCalled)
        XCTAssertEqual(progress.imported, 1)

        let state = try repo.syncState(forUserID: "user-42")
        XCTAssertTrue(state.historicalImportComplete)
        XCTAssertTrue(state.accessLinkRegistered)
    }

    func test_subsequentLaunch_onlyCallsAccessLink() async throws {
        // Pre-seed state as already completed first launch
        let state = try repo.syncState(forUserID: "user-42")
        state.historicalImportComplete = true
        state.accessLinkRegistered = true
        try context.save()

        mockAccessLink.stubbedActivities = [makeActivity(id: "new-1")]

        _ = try await coordinator.sync(userID: "user-42")

        XCTAssertFalse(mockFlowWeb.fetchAllCalled)
        XCTAssertFalse(mockAccessLink.registerCalled)

        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, "new-1")
    }

    func test_deduplication_doesNotDoubleCount() async throws {
        try repo.save(makeActivity(id: "shared-1"))

        let state = try repo.syncState(forUserID: "user-42")
        state.historicalImportComplete = true
        state.accessLinkRegistered = true
        try context.save()

        mockAccessLink.stubbedActivities = [makeActivity(id: "shared-1"), makeActivity(id: "new-2")]

        _ = try await coordinator.sync(userID: "user-42")

        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 2)  // shared-1 + new-2, no duplicate
    }
}

// MARK: - Mock clients

class MockAccessLinkClient: AccessLinkClientProtocol {
    var registerCalled = false
    var stubbedUserID = "user-1"
    var stubbedActivities: [Activity] = []

    func registerUser() async throws -> String {
        registerCalled = true
        return stubbedUserID
    }
    func pullNewActivities() async throws -> [Activity] { stubbedActivities }
}

class MockFlowWebClient: FlowWebClientProtocol {
    var fetchAllCalled = false
    var stubbedActivities: [Activity] = []

    func fetchAllActivities() async throws -> [Activity] {
        fetchAllCalled = true
        return stubbedActivities
    }
}
