import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    let syncMessage: String?
    let isSyncing: Bool

    var body: some View {
        if authManager.isAuthenticated {
            MainTabView(syncMessage: syncMessage, isSyncing: isSyncing)
        } else {
            LoginView()
        }
    }
}

struct MainTabView: View {
    let syncMessage: String?
    let isSyncing: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isSyncing || syncMessage != nil {
                HStack(spacing: 8) {
                    if isSyncing { ProgressView().scaleEffect(0.8) }
                    Text(syncMessage ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.bar)
            }
            TabView {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                ActivityListView()
                    .tabItem { Label("Activities", systemImage: "list.bullet") }
                TracksPlaceholderView()
                    .tabItem { Label("Tracks", systemImage: "map") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
        }
    }
}

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            Text("Polar MyFlow")
                .font(.largeTitle.bold())
            Text("Connect your Polar account to view your training history.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }
            Button {
                Task {
                    isAuthenticating = true
                    errorMessage = nil
                    do { try await authManager.authenticate() }
                    catch { errorMessage = error.localizedDescription }
                    isAuthenticating = false
                }
            } label: {
                if isAuthenticating {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Connect with Polar").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating)
            .padding(.horizontal)
            Spacer()
        }
        .padding()
    }
}
