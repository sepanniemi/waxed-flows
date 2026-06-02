import SwiftUI

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActivityDetailViewModel
    @State private var scrubFraction: Double = 0.0
    @State private var scrubSpeedKmh: Double = 0.0
    @State private var recenterToken: Int = 0
    @State private var cachedRoutePoints: [RoutePoint]

    init(activity: Activity) {
        _viewModel = State(initialValue: ActivityDetailViewModel(activity: activity))
        _cachedRoutePoints = State(initialValue: activity.hasRoute ? activity.routePoints : [])
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(viewModel)
                    if viewModel.activity.hasRoute {
                        mapFirstLayout(viewModel, geo: geo)
                    } else {
                        numbersFirstLayout(viewModel)
                    }
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
        }
        .polarBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Map-first layout (hasRoute == true)

    private func mapFirstLayout(_ vm: ActivityDetailViewModel, geo: GeometryProxy) -> some View {
        let mapHeight = max(360, geo.size.height * 0.55)
        return VStack(spacing: 12) {
            trackSection(height: mapHeight)
            PolarRule(variant: .full)
            compactStatStrip(vm)
        }
    }

    private func trackSection(height: CGFloat) -> some View {
        VStack(spacing: 12) {
            TrackMapView(routePoints: cachedRoutePoints,
                         scrubFraction: $scrubFraction,
                         speedKmh: $scrubSpeedKmh,
                         recenterToken: $recenterToken)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        recenterToken += 1
                    } label: {
                        Image(systemName: "scope")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(12)
                    .accessibilityLabel("Recenter map on route")
                }
                .overlay(alignment: .bottomLeading) {
                    if !BuildConfig.mmlApiKey.isEmpty {
                        Text("© Maanmittauslaitos")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(white: 0.15).opacity(0.8))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 3))
                            .padding(6)
                    }
                }
                .padding(.horizontal, -Spacing.screenMargin)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", scrubSpeedKmh))
                    .font(.displaySmall)
                    .foregroundStyle(Palette.ink)
                    .displayShadow()
                Text("km/h").metaLabel()
                Spacer()
            }
            Slider(value: $scrubFraction, in: 0...1)
                .tint(Palette.polarAmber)
        }
    }

    private func compactStatStrip(_ vm: ActivityDetailViewModel) -> some View {
        HStack(alignment: .top, spacing: 0) {
            statCell(value: vm.distanceString, label: "Distance")
            Spacer()
            statCell(value: vm.durationString, label: "Moving")
            Spacer()
            statCell(value: vm.speedString, label: "Speed")
            if let hr = vm.avgHRString {
                Spacer()
                statCell(value: hr, label: "Avg HR")
            }
        }
    }

    // MARK: - Numbers-first layout (hasRoute == false)

    private func numbersFirstLayout(_ vm: ActivityDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            heroStats(vm)
            PolarRule(variant: .full)
            threeUp(vm)
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
            }
        }
    }

    // MARK: - Shared helpers

    private func header(_ vm: ActivityDetailViewModel) -> some View {
        PolarBackHeader(
            crumb: "Log · \(vm.dateString)",
            title: vm.title,
            titleFont: .displaySmall,
            onDismiss: { dismiss() }
        )
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
