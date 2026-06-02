import Foundation

// Single source of truth for how training metrics render in the UI.
// Metres → km, s/m pace → min:ss /km, seconds → H:MM:SS / M:SS.
enum ActivityFormatting {

    static func distanceKm(_ metres: Double, precision: Int = 1) -> String {
        String(format: "%.\(precision)f km", metres / 1000)
    }

    // `pace` is seconds per metre (as stored on Activity).
    static func paceMinPerKm(_ secondsPerMetre: Double) -> String {
        guard secondsPerMetre > 0 else { return "—" }
        let secondsPerKm = Int(secondsPerMetre * 1000)
        return String(format: "%d:%02d /km", secondsPerKm / 60, secondsPerKm % 60)
    }

    static func speedKmh(_ metresPerSecond: Double) -> String {
        String(format: "%.1f km/h", metresPerSecond * 3.6)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
