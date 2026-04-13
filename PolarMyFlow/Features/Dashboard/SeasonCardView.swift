import SwiftUI

struct SeasonCardView: View {
    let summary: SeasonSummary
    let onTapSport: (SportType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(summary.season.label)
                .font(.headline)
                .padding([.horizontal, .top])

            Divider().padding(.top, 8)

            ForEach(summary.sportSummaries) { sport in
                Button {
                    onTapSport(sport.sport)
                } label: {
                    SportRowView(summary: sport)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 52)
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

struct SportRowView: View {
    let summary: SportSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: summary.sport.symbolName)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.sport.displayName)
                    .font(.subheadline.weight(.medium))
                Text("\(summary.sessionCount) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDistance(summary.totalDistance))
                    .font(.subheadline.weight(.semibold))
                Text(formatPace(summary.avgPace))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func formatDistance(_ metres: Double) -> String {
        let km = metres / 1000
        return String(format: "%.1f km", km)
    }

    // pace in s/m → format as min:ss /km
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "—" }
        let secPerKm = pace * 1000
        let min = Int(secPerKm) / 60
        let sec = Int(secPerKm) % 60
        return String(format: "%d:%02d /km", min, sec)
    }
}
