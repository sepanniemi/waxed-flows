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
                    await startSyncIfAuthenticated()
                }
                .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                    guard isAuthenticated else { return }
                    Task { await startSyncIfAuthenticated() }
                }
                #if DEBUG
                .onReceive(NotificationCenter.default.publisher(for: .debugResetSync)) { _ in
                    Task { await startSyncIfAuthenticated() }
                }
                #endif
        }
    }

    @MainActor
    private func startSyncIfAuthenticated() async {
        guard authManager.isAuthenticated, let token = authManager.currentToken else { return }
        #if DEBUG
        print("🔑 ACCESS TOKEN: \(token.accessToken)")
        print("🔑 REFRESH TOKEN: \(token.refreshToken)")
        #endif

        // On first login userID is unknown — register with AccessLink to get it
        let userID: String
        if let knownID = authManager.currentUserID {
            userID = knownID
        } else {
            isSyncing = true
            syncMessage = "Connecting to Polar..."
            do {
                let accessLinkClient = PolarAccessLinkClient(accessToken: token.accessToken)
                let fetchedID = try await accessLinkClient.registerUser()
                authManager.setUserID(fetchedID)
                userID = fetchedID
            } catch {
                syncMessage = "Could not connect: \(error.localizedDescription)"
                isSyncing = false
                return
            }
        }

        await runSync(token: token, userID: userID)
    }

    @MainActor
    private func runSync(token: AuthToken, userID: String) async {
        isSyncing = true
        syncMessage = "Syncing with Polar..."

        let context = ModelContext(sharedModelContainer)
        let repo = ActivityRepository(context: context)
        let accessLinkClient = PolarAccessLinkClient(accessToken: token.accessToken)
        let coordinator = SyncCoordinator(repository: repo, accessLinkClient: accessLinkClient)

        do {
            let progress = try await coordinator.sync(userID: userID)
            if progress.imported > 0 {
                syncMessage = "Imported \(progress.imported) new activities"
            } else {
                syncMessage = nil
            }
        } catch {
            syncMessage = "Sync failed: \(error.localizedDescription)"
        }

        isSyncing = false
    }
}
