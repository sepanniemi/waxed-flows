import SwiftUI
import SwiftData

struct SportDetailView: View {
    let sport: SportType
    let season: Season
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SportDetailViewModel?

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
                .padding(.horizontal, 20)
                .padding(.top, 48)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { dismiss() } label: {
                Text("◂ Dash · \(season.label)")
                    .metaLabel()
            }
            .buttonStyle(.plain)
            PolarRule(variant: .soft)
            Text(sport.displayName)
                .font(.displayMedium)
                .textCase(.uppercase)
                .foregroundStyle(Palette.polarSkyLight)
                .displayShadow()
        }
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
                    set: { vm.startDate = $0; Task { await vm.load() } }
                ), displayedComponents: .date)
                    .font(.bodyDefault)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.polarSky)
                DatePicker("To", selection: Binding(
                    get: { vm.endDate },
                    set: { vm.endDate = $0; Task { await vm.load() } }
                ), displayedComponents: .date)
                    .font(.bodyDefault)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.polarSky)
            }
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
