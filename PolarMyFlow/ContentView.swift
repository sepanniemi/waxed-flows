import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    let syncMessage: String?
    let isSyncing: Bool

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView(syncMessage: syncMessage, isSyncing: isSyncing)
            } else {
                LoginView()
            }
        }
        .polarBackground()
    }
}

struct MainTabView: View {
    let syncMessage: String?
    let isSyncing: Bool
    @State private var selection: PolarTab = .dash

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .padding(.bottom, 80)  // room for custom tab bar

            VStack(spacing: 0) {
                if isSyncing || syncMessage != nil {
                    syncPill
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                }
                Spacer()
                PolarTabBar(selection: $selection)
            }
        }
    }

    @ViewBuilder private var tabContent: some View {
        switch selection {
        case .dash:     DashboardView()
        case .log:      ActivityListView()
        case .tracks:   TracksPlaceholderView()
        case .settings: SettingsView()
        }
    }

    @ViewBuilder private var syncPill: some View {
        HStack(spacing: 8) {
            if isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(Palette.polarSkyLight)
            }
            if let syncMessage {
                Text(syncMessage)
                    .font(.metaSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.inkMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Palette.surfaceGlass, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.surfaceBorder, lineWidth: 1))
    }
}

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                (Text("Waxed\n").foregroundStyle(Palette.ink)
                 + Text("Flows.").foregroundStyle(Palette.polarSkyLight))
                    .font(.displayMedium)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-4)
                    .displayShadow()

                Text("Your season · your line")
                    .metaLabel()
            }

            PolarRule(variant: .soft)
                .frame(maxWidth: 220)

            Text("Connect your Polar account to view your training history.")
                .font(.bodyDefault)
                .foregroundStyle(Palette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let errorMessage {
                Text(errorMessage)
                    .font(.bodyCaption)
                    .foregroundStyle(Palette.polarAmber)
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
                Group {
                    if isAuthenticating {
                        ProgressView().tint(Palette.polarNight)
                    } else {
                        Text("Connect")
                            .font(.displayTab)
                            .tracking(0.8)
                            .textCase(.uppercase)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Palette.polarNight)
                .background(Palette.polarSky, in: RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isAuthenticating)
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
