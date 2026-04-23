import SwiftUI
import SwiftData

struct ActivityListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ActivityListViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    List {
                        if !vm.availableSports.isEmpty {
                            Section {
                                Picker("Sport", selection: Binding(
                                    get: { vm.selectedSport },
                                    set: { vm.selectedSport = $0 }
                                )) {
                                    Text("All sports").tag(SportType?.none)
                                    ForEach(vm.availableSports, id: \.self) { sport in
                                        Label(sport.displayName, systemImage: "circle")
                                            .tag(SportType?.some(sport))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        if vm.activities.isEmpty {
                            ContentUnavailableView(
                                "No activities",
                                systemImage: "figure.run",
                                description: Text("No activities found for the selected filter.")
                            )
                        } else {
                            ForEach(vm.activities, id: \.id) { activity in
                                NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                    ActivityRowView(activity: activity)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Activities")
        }
        .task {
            if viewModel == nil {
                let repo = ActivityRepository(context: modelContext)
                viewModel = ActivityListViewModel(repository: repo)
            }
            await viewModel?.load()
        }
        .onAppear {
            Task { await viewModel?.load() }
        }
    }
}
