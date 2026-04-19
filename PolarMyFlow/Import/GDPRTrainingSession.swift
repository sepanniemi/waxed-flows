import Foundation

// Schema is a best-effort match for Polar's GDPR export based on publicly
// observed exports. Verify against an actual user export before release;
// adjust keys / nesting here if the real schema differs.
struct GDPRTrainingSession: Decodable {
    let startTime: String
    let duration: String
    let distance: Double?
    let sport: String?
    let exercises: [Exercise]?

    struct Exercise: Decodable {
        let sport: String?
        let startTime: String?
        let duration: String?
        let distance: Double?
        let heartRate: HeartRate?
        let calories: Int?
        let ascent: Double?
        let descent: Double?
    }

    struct HeartRate: Decodable {
        let avg: Int?
        let max: Int?
    }

    // Maps the session + its first exercise into an Activity. Returns nil if
    // start time or duration can't be parsed. fileID is used as Activity.id
    // because the JSON itself does not carry a stable numeric ID we can trust.
    func toActivity(fileID: String) -> Activity? {
        guard let dur = Self.parseISO8601Duration(duration) else { return nil }
        guard let start = Self.parseDate(startTime) else { return nil }

        let ex = exercises?.first
        let sportStr = ex?.sport ?? sport ?? SportType.other.rawValue
        let dist = ex?.distance ?? distance ?? 0.0
        let speed = dist > 0 ? dist / dur : 0.0
        let pace  = dist > 0 ? dur / dist : 0.0

        return Activity(
            id: fileID,
            startTime: start,
            duration: dur,
            distance: dist,
            sportRawValue: sportStr,
            avgSpeed: speed,
            avgPace: pace,
            avgHeartRate: ex?.heartRate?.avg,
            maxHeartRate: ex?.heartRate?.max,
            ascent: ex?.ascent,
            descent: ex?.descent,
            calories: ex?.calories,
            hasRoute: false
        )
    }

    // Polar GDPR export uses local-time strings like "2025-01-15T09:00:00.000"
    // (no timezone offset). Parse as POSIX local time.
    static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let d = formatter.date(from: string) { return d }
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: string)
    }

    // Mirrors PolarAccessLinkClient.parseISO8601Duration for PT-prefixed
    // durations: "PT1H30M0S", "PT42M1S", "PT30S".
    static func parseISO8601Duration(_ string: String) -> TimeInterval? {
        guard string.hasPrefix("PT") else { return nil }
        var remaining = String(string.dropFirst(2))
        var total: Double = 0
        for (unit, multiplier) in [("H", 3600.0), ("M", 60.0), ("S", 1.0)] {
            if let range = remaining.range(of: unit) {
                let valueStr = String(remaining[remaining.startIndex..<range.lowerBound])
                if let value = Double(valueStr) { total += value * multiplier }
                remaining = String(remaining[range.upperBound...])
            }
        }
        return total > 0 ? total : nil
    }
}
