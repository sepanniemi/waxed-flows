import SwiftUI
import SwiftData

enum DashboardRoute: Hashable {
    case sportDetail(SportType, Season)
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .polarBackground()
                .navigationBarHidden(true)
                .navigationDestination(for: DashboardRoute.self) { route in
                    switch route {
                    case .sportDetail(let sport, let season):
                        SportDetailView(sport: sport, season: season)
                    }
                }
        }
        .task {
            let repo = ActivityRepository(context: modelContext)
            let vm = DashboardViewModel(repository: repo)
            viewModel = vm
            await vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncDidComplete)) { _ in
            Task { await viewModel?.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .debugResetSync)) { _ in
            Task {
                let repo = ActivityRepository(context: modelContext)
                let vm = DashboardViewModel(repository: repo)
                viewModel = vm
                await vm.load()
            }
        }
    }

    @ViewBuilder private var content: some View {
        if let vm = viewModel {
            if vm.isLoading {
                ProgressView().tint(Palette.polarSkyLight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.seasons.isEmpty {
                PolarEmptyState(
                    title: "No Sessions Yet",
                    description: "Sync your Polar account to see your training history."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        ForEach(vm.seasons) { season in
                            SeasonCardView(summary: season) { sport in
                                navigationPath.append(DashboardRoute.sportDetail(sport, season.season))
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.top, Spacing.screenTop)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dashboard · Seasons")
                .metaLabel()
            PolarRule(variant: .soft)
            (Text("Waxed\n").foregroundStyle(Palette.ink)
             + Text("Flows.").foregroundStyle(Palette.polarSkyLight))
                .font(.displayMedium)
                .lineSpacing(-4)
                .displayShadow()
        }
    }
}
