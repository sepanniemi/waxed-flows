import SwiftUI
import SwiftData

struct SportDetailView: View {
    let sport: SportType
    let season: Season
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SportDetailViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    Section {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(vm.totalDistance)
                                    .font(.title2.bold())
                                Text("Total distance")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(vm.sessionCount)
                                    .font(.title2.bold())
                                Text("Sessions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Date Range") {
                        DatePicker("From", selection: Binding(
                            get: { vm.startDate },
                            set: { vm.startDate = $0; Task { await vm.load() } }
                        ), displayedComponents: .date)
                        DatePicker("To", selection: Binding(
                            get: { vm.endDate },
                            set: { vm.endDate = $0; Task { await vm.load() } }
                        ), displayedComponents: .date)
                    }

                    Section("Activities") {
                        if vm.activities.isEmpty {
                            Text("No activities in this range")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(vm.activities, id: \.id) { activity in
                                NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                    ActivityRowView(activity: activity)
                                }
                            }
                        }
                    }
                }
                .navigationTitle(sport.displayName)
            }
        }
        .task {
            let repo = ActivityRepository(context: modelContext)
            let vm = SportDetailViewModel(sport: sport, season: season, repository: repo)
            viewModel = vm
            await vm.load()
        }
    }
}
