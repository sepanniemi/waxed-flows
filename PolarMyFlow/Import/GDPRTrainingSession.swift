import Foundation

// Schema matches the real Polar GDPR export format (verified against actual
// 4.4 GB export spanning 2012–2026). Fields use the real JSON keys.
struct GDPRTrainingSession: Decodable {
    let startTime: String
    let durationMillis: Int
    let distanceMeters: Double?
    let calories: Int?
    let hrAvg: Int?
    let hrMax: Int?
    let sport: SportRef?
    let exercises: [Exercise]?

    struct SportRef: Decodable { let id: String }
    struct Exercise: Decodable {
        let ascentMeters: Double?
        let descentMeters: Double?
    }

    // Maps the session into an Activity. Returns nil if duration is zero or
    // start time can't be parsed. fileID is used as Activity.id because the
    // JSON itself does not carry a stable numeric ID we can trust.
    func toActivity(fileID: String) -> Activity? {
        guard durationMillis > 0 else { return nil }
        guard let start = Self.parseDate(startTime) else { return nil }

        let dur = Double(durationMillis) / 1000.0
        let dist = distanceMeters ?? 0.0
        let speed = dist > 0 ? dist / dur : 0.0
        let pace  = dist > 0 ? dur / dist : 0.0

        let sportId = sport.flatMap { Int($0.id) } ?? -1
        let sportStr = SportType.from(polarSportId: sportId).rawValue

        return Activity(
            id: fileID,
            startTime: start,
            duration: dur,
            distance: dist,
            sportRawValue: sportStr,
            avgSpeed: speed,
            avgPace: pace,
            avgHeartRate: hrAvg,
            maxHeartRate: hrMax,
            ascent: exercises?.first?.ascentMeters,
            descent: exercises?.first?.descentMeters,
            calories: calories,
            hasRoute: false
        )
    }

    // Polar GDPR export uses naive local-time strings like
    // "2025-01-15T09:00:00.000" with no timezone offset. We interpret the
    // wall clock in the device's current timezone — same policy AccessLink
    // uses — so a session shows the same time the user sees in Polar Flow.
    // DateFormatter defaults to the system TZ when timeZone is unset.
    static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let d = formatter.date(from: string) { return d }
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: string)
    }
}
