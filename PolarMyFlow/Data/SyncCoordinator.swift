import Foundation

struct SyncProgress {
    let imported: Int
    let errors: [Error]
}

final class SyncCoordinator {
    private let repository: ActivityRepository
    private let accessLinkClient: AccessLinkClientProtocol
    private let flowWebClient: FlowWebClientProtocol

    init(
        repository: ActivityRepository,
        accessLinkClient: AccessLinkClientProtocol,
        flowWebClient: FlowWebClientProtocol
    ) {
        self.repository = repository
        self.accessLinkClient = accessLinkClient
        self.flowWebClient = flowWebClient
    }

    // Main entry point. Call on every app launch with the authenticated user's ID.
    @discardableResult
    func sync(userID: String) async throws -> SyncProgress {
        let state = try repository.syncState(forUserID: userID)
        var imported = 0
        var errors: [Error] = []

        if !state.historicalImportComplete {
            // First launch: import history then register with AccessLink
            do {
                let historical = try await flowWebClient.fetchAllActivities()
                for activity in historical {
                    try repository.save(activity)
                    imported += 1
                }
                state.historicalImportComplete = true
            } catch {
                errors.append(error)
            }

            if !state.accessLinkRegistered {
                do {
                    _ = try await accessLinkClient.registerUser()
                    state.accessLinkRegistered = true
                } catch {
                    errors.append(error)
                }
            }
        } else {
            // Subsequent launches: AccessLink only
            do {
                let newActivities = try await accessLinkClient.pullNewActivities()
                for activity in newActivities {
                    try repository.save(activity)
                    imported += 1
                }
            } catch {
                errors.append(error)
            }
        }

        state.lastSyncedAt = Date()
        try repository.saveSyncState()

        return SyncProgress(imported: imported, errors: errors)
    }
}
