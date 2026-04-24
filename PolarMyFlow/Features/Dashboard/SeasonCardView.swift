import SwiftUI

struct SeasonCardView: View {
    let summary: SeasonSummary
    let onTapSport: (SportType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(summary.season.label)
                .metaLabel(.metaDefault, color: Palette.inkMuted)

            VStack(spacing: 10) {
                ForEach(summary.sportSummaries) { sport in
                    Button {
                        onTapSport(sport.sport)
                    } label: {
                        SportRowView(summary: sport)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct SportRowView: View {
    let summary: SportSummary

    var body: some View {
        PolarCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(summary.sport.dotColor)
                        .frame(width: 6, height: 6)
                    Text(summary.sport.displayName)
                        .metaLabel(.metaDefault, color: Palette.ink)
                        .tracking(1.4)
                    Spacer()
                    PolarBadge(text: "\(summary.sessionCount) Sessions")
                }

                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(ActivityFormatting.distanceKm(summary.totalDistance))
                            .font(.displayLarge)
                            .foregroundStyle(Palette.ink)
                            .displayShadow()
                        Text("km")
                            .font(.bodyCaption)
                            .foregroundStyle(Palette.inkMuted)
                    }
                    Spacer()
                    Text("Avg \(ActivityFormatting.paceMinPerKm(summary.avgPace))")
                        .font(.bodyCaption)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
        }
    }
}
