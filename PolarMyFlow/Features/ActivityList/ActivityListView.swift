import SwiftUI
import SwiftData

struct ActivityListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ActivityListViewModel?

    var body: some View {
        NavigationStack {
            content
                .polarBackground()
                .navigationBarHidden(true)
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

    @ViewBuilder private var content: some View {
        if let vm = viewModel {
            VStack(alignment: .leading, spacing: 0) {
                header
                if !vm.availableSports.isEmpty {
                    filterRow(vm)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }
                if vm.activities.isEmpty {
                    PolarEmptyState(
                        title: "No Sessions Found",
                        description: "Try a different sport filter or sync your Polar account."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.activities, id: \.id) { activity in
                                NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                    ActivityRowView(activity: activity)
                                }
                                .buttonStyle(.plain)
                                PolarRule(variant: .full)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.top, 48)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Log · All Sessions")
                .metaLabel()
            PolarRule(variant: .soft)
        }
        .padding(.horizontal, 20)
    }

    private func filterRow(_ vm: ActivityListViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterBadge(
                    text: "All",
                    selected: vm.selectedSport == nil,
                    action: { vm.selectedSport = nil }
                )
                ForEach(vm.availableSports, id: \.self) { sport in
                    filterBadge(
                        text: sport.displayName,
                        selected: vm.selectedSport == sport,
                        action: { vm.selectedSport = sport }
                    )
                }
            }
        }
    }

    private func filterBadge(text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PolarBadge(text: text, style: selected ? .filled : .outline)
        }
        .buttonStyle(.plain)
    }
}
