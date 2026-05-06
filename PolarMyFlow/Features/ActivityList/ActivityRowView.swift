import SwiftUI

struct ActivityRowView: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                SportGlyph(sport: activity.sportType, size: 24)
                Circle()
                    .fill(activity.sportType.dotColor)
                    .frame(width: 6, height: 6)
                    .offset(x: 2, y: 2)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.sportType.displayName)
                    .font(.displaySmall)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.ink)
                Text(activity.startTime.formatted(date: .abbreviated, time: .shortened))
                    .metaLabel()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ActivityFormatting.distanceKm(activity.distance))
                    .font(.displaySmall)
                    .foregroundStyle(Palette.ink)
                    .displayShadow()
                if let hr = activity.avgHeartRate {
                    Text("\(hr) bpm")
                        .font(.bodyCaption)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
