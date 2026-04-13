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

    var durationString: String {
        let h = Int(activity.duration) / 3600
        let m = (Int(activity.duration) % 3600) / 60
        let s = Int(activity.duration) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var distanceString: String {
        String(format: "%.2f km", activity.distance / 1000)
    }

    var paceString: String {
        let secPerKm = activity.avgPace * 1000
        let min = Int(secPerKm) / 60
        let sec = Int(secPerKm) % 60
        return String(format: "%d:%02d /km", min, sec)
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
