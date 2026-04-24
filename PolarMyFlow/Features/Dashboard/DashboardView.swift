import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @State private var navigationPath = NavigationPath()
    @State private var selectedSport: SportType?
    @State private var selectedSeason: Season?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .polarBackground()
                .navigationBarHidden(true)
                .navigationDestination(for: String.self) { _ in
                    if let sport = selectedSport, let season = selectedSeason {
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
                                selectedSport = sport
                                selectedSeason = season.season
                                navigationPath.append("sport-detail")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 48)
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
