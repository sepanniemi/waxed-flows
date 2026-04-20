import Foundation

@Observable
final class ActivityDetailViewModel {
    let activity: Activity

    init(activity: Activity) {
        self.activity = activity
    }

    var title: String {
        activity.sportType.displayName
    }

    var dateString: String {
        activity.startTime.formatted(date: .long, time: .shortened)
    }

    var durationString: String { ActivityFormatting.duration(activity.duration) }

    var distanceString: String {
        ActivityFormatting.distanceKm(activity.distance, precision: 2)
    }

    var paceString: String {
        ActivityFormatting.paceMinPerKm(activity.avgPace)
    }

    var avgHRString: String? {
        activity.avgHeartRate.map { "\($0) bpm" }
    }

    var maxHRString: String? {
        activity.maxHeartRate.map { "\($0) bpm" }
    }

    var ascentString: String? {
        activity.ascent.map { String(format: "↑ %.0f m", $0) }
    }

    var descentString: String? {
        activity.descent.map { String(format: "↓ %.0f m", $0) }
    }

    var caloriesString: String? {
        activity.calories.map { "\($0) kcal" }
    }
}
