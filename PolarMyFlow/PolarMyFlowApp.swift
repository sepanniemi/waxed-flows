import SwiftUI
import SwiftData

@main
struct PolarMyFlowApp: App {
    @State private var authManager = AuthManager()
    @State private var syncMessage: String?
    @State private var isSyncing = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Activity.self, SyncState.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(syncMessage: syncMessage, isSyncing: isSyncing)
                .environment(authManager)
                .modelContainer(sharedModelContainer)
                .task {
                    authManager.restoreSession()
                    guard authManager.isAuthenticated,
                          let token = authManager.currentToken,
                          let userID = authManager.currentUserID
                    else { return }
                    await runSync(token: token, userID: userID)
                }
        }
    }

    @MainActor
    private func runSync(token: AuthToken, userID: String) async {
        isSyncing = true
        syncMessage = "Syncing with Polar..."

        let container = sharedModelContainer
        let context = ModelContext(container)
        let repo = ActivityRepository(context: context)
        let accessLinkClient = PolarAccessLinkClient(accessToken: token.accessToken)
        let flowWebClient = PolarFlowWebClient(userID: userID)
        let coordinator = SyncCoordinator(
            repository: repo,
            accessLinkClient: accessLinkClient,
            flowWebClient: flowWebClient
        )

        do {
            let state = try repo.syncState(forUserID: userID)
            if !state.historicalImportComplete {
                syncMessage = "Importing your training history..."
            }
            let progress = try await coordinator.sync(userID: userID)
            if progress.imported > 0 {
                syncMessage = "Imported \(progress.imported) new activities"
            } else {
                syncMessage = nil
            }
        } catch {
            syncMessage = nil
        }

        isSyncing = false
    }
}
