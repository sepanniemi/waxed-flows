import SwiftUI
import SwiftData

struct SportDetailView: View {
    let sport: SportType
    let season: Season
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SportDetailViewModel?
    @State private var reloadTask: Task<Void, Never>?

    var body: some View {
        content
            .polarBackground()
            .navigationBarHidden(true)
            .task {
                let repo = ActivityRepository(context: modelContext)
                let vm = SportDetailViewModel(sport: sport, season: season, repository: repo)
                viewModel = vm
                await vm.load()
            }
    }

    @ViewBuilder private var content: some View {
        if let vm = viewModel {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summaryRow(vm)
                    datePickerBlock(vm)
                    activitiesBlock(vm)
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, Spacing.screenTop)
            }
        } else {
            ProgressView()
                .tint(Palette.polarSkyLight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        PolarBackHeader(
            crumb: "Dash · \(season.label)",
            title: sport.displayName,
            onDismiss: { dismiss() }
        )
    }

    private func summaryRow(_ vm: SportDetailViewModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            statBlock(value: vm.totalDistance, unit: "Total")
            Spacer()
            statBlock(value: vm.sessionCount, unit: "Sessions")
        }
    }

    private func statBlock(value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.displaySmall)
                .foregroundStyle(Palette.ink)
                .displayShadow()
            Text(unit).metaLabel()
        }
    }

    private func datePickerBlock(_ vm: SportDetailViewModel) -> some View {
        PolarCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Date Range").metaLabel()
                DatePicker("From", selection: Binding(
                    get: { vm.startDate },
                    set: { vm.startDate = $0; scheduleReload(vm) }
                ), displayedComponents: .date)
                    .font(.bodyDefault)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.polarSky)
                DatePicker("To", selection: Binding(
                    get: { vm.endDate },
                    set: { vm.endDate = $0; scheduleReload(vm) }
                ), displayedComponents: .date)
                    .font(.bodyDefault)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.polarSky)
            }
        }
    }

    private func scheduleReload(_ vm: SportDetailViewModel) {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await vm.load()
        }
    }

    @ViewBuilder
    private func activitiesBlock(_ vm: SportDetailViewModel) -> some View {
        Text("Sessions").metaLabel()
        if vm.activities.isEmpty {
            Text("No activities in this range")
                .font(.bodyDefault)
                .foregroundStyle(Palette.inkMuted)
        } else {
            VStack(spacing: 0) {
                ForEach(vm.activities, id: \.id) { activity in
                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                        ActivityRowView(activity: activity)
                    }
                    .buttonStyle(.plain)
                    PolarRule(variant: .full)
                }
            }
        }
    }
}
