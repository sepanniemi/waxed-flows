import SwiftUI

struct ActivityRowView: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.sportType.displayName)
                    .font(.subheadline.weight(.medium))
                Text(activity.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ActivityFormatting.distanceKm(activity.distance))
                    .font(.subheadline.weight(.semibold))
                if let hr = activity.avgHeartRate {
                    Text("\(hr) bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
