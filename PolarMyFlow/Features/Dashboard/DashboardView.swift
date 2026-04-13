import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @State private var navigationPath = NavigationPath()
    @State private var selectedSport: SportType?
    @State private var selectedSeason: Season?
    #if DEBUG
    @State private var showDebug = false
    #endif

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let vm = viewModel {
                    if vm.isLoading {
                        ProgressView("Loading training history...")
                    } else if vm.seasons.isEmpty {
                        ContentUnavailableView(
                            "No training data",
                            systemImage: "figure.run",
                            description: Text("Sync your Polar account to see your training history.")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(vm.seasons) { season in
                                    SeasonCardView(summary: season) { sport in
                                        selectedSport = sport
                                        selectedSeason = season.season
                                        navigationPath.append("sport-detail")
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationDestination(for: String.self) { _ in
                if let sport = selectedSport, let season = selectedSeason {
                    SportDetailView(sport: sport, season: season)
                }
            }
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showDebug = true } label: {
                        Image(systemName: "wrench.and.screwdriver")
                    }
                }
            }
            .sheet(isPresented: $showDebug) {
                DebugSettingsView()
            }
            #endif
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
}
