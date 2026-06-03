import Foundation

final class SyncCoordinator {
    private let repository: ActivityRepository
    private let accessLinkClient: AccessLinkClientProtocol

    init(repository: ActivityRepository, accessLinkClient: AccessLinkClientProtocol) {
        self.repository = repository
        self.accessLinkClient = accessLinkClient
    }

    // Pull any new activities from AccessLink and save them.
    // On first call after registration this returns all historical activities.
    // On subsequent calls it returns only activities added since the last commit.
    @discardableResult
    func sync(userID: String) async throws -> Int {
        let state = try repository.syncState(forUserID: userID)
        let activities = try await accessLinkClient.pullNewActivities(since: state.lastSyncedAt)
        var imported = 0
        for activity in activities {
            try repository.save(activity)
            imported += 1
        }
        state.lastSyncedAt = Date()
        try repository.saveSyncState()
        return imported
    }
}
