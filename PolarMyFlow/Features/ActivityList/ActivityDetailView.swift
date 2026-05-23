import SwiftUI

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActivityDetailViewModel
    @State private var scrubFraction: Double = 0.0
    @State private var cachedRoutePoints: [RoutePoint] = []

    init(activity: Activity) {
        _viewModel = State(initialValue: ActivityDetailViewModel(activity: activity))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(viewModel)
                heroStats(viewModel)
                PolarRule(variant: .full)
                threeUp(viewModel)
                if viewModel.activity.hasRoute {
                    PolarRule(variant: .full)
                    trackSection()
                }
                // FIXME: HR zone chart not wired — Activity model has no zone-time data.
                if viewModel.ascentString != nil || viewModel.descentString != nil {
                    PolarRule(variant: .full)
                    elevation(viewModel)
                }
                if let calories = viewModel.caloriesString {
                    PolarRule(variant: .full)
                    energy(calories)
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.screenTop)
        }
        .polarBackground()
        .onAppear {
            if viewModel.activity.hasRoute {
                cachedRoutePoints = viewModel.activity.routePoints
            }
        }
        .navigationBarHidden(true)
    }

    private func header(_ vm: ActivityDetailViewModel) -> some View {
        PolarBackHeader(
            crumb: "Log · \(vm.dateString)",
            title: vm.title,
            titleFont: .displaySmall,
            onDismiss: { dismiss() }
        )
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
            }
        }
    }

    private func trackSection() -> some View {
        PolarCard {
            VStack(spacing: 12) {
                TrackMapView(routePoints: cachedRoutePoints, scrubFraction: $scrubFraction)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Slider(value: $scrubFraction, in: 0...1)
                    .tint(Palette.polarAmber)
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
