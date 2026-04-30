import SwiftUI

struct ActivityDetailView: View {
    let activity: Activity
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActivityDetailViewModel?

    var body: some View {
        content
            .polarBackground()
            .navigationBarHidden(true)
            .onAppear { viewModel = ActivityDetailViewModel(activity: activity) }
    }

    @ViewBuilder private var content: some View {
        if let vm = viewModel {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(vm)
                    heroStats(vm)
                    PolarRule(variant: .full)
                    threeUp(vm)
                    // FIXME: HR zone chart not wired — Activity model has no zone-time data.
                    if vm.ascentString != nil || vm.descentString != nil {
                        PolarRule(variant: .full)
                        elevation(vm)
                    }
                    if let calories = vm.caloriesString {
                        PolarRule(variant: .full)
                        energy(calories)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 48)
            }
        }
    }

    private func header(_ vm: ActivityDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { dismiss() } label: {
                Text("◂ Log · \(vm.dateString)")
                    .metaLabel()
            }
            .buttonStyle(.plain)
            PolarRule(variant: .soft)
            Text(vm.title)
                .font(.displaySmall)
                .textCase(.uppercase)
                .foregroundStyle(Palette.polarSkyLight)
                .displayShadow()
        }
    }

    private func heroStats(_ vm: ActivityDetailViewModel) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.distanceString)
                    .font(.displayJumbo)
                    .foregroundStyle(Palette.ink)
                    .displayShadow()
                Text("Km").metaLabel()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(vm.durationString)
                    .font(.displaySmall)
                    .foregroundStyle(Palette.polarSkyLight)
                Text("Moving").metaLabel()
            }
        }
    }

    private func threeUp(_ vm: ActivityDetailViewModel) -> some View {
        HStack(alignment: .top, spacing: 20) {
            statCell(value: vm.paceString, label: "Pace /km")
            Spacer()
            if let hr = vm.avgHRString {
                statCell(value: hr, label: "Avg HR")
                Spacer()
            }
            if let asc = vm.ascentString {
                statCell(value: asc, label: "Ascent m")
            }
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.displaySmall)
                .foregroundStyle(Palette.ink)
                .displayShadow()
            Text(label).metaLabel()
        }
    }

    private func elevation(_ vm: ActivityDetailViewModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            if let asc = vm.ascentString {
                statCell(value: asc, label: "Ascent")
            }
            Spacer()
            if let desc = vm.descentString {
                statCell(value: desc, label: "Descent")
            }
        }
    }

    private func energy(_ calories: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(calories)
                .font(.displaySmall)
                .foregroundStyle(Palette.ink)
                .displayShadow()
            Text("Energy").metaLabel()
        }
    }
}
