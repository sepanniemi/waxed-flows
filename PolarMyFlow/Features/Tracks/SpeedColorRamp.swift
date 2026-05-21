import UIKit

// A2 colour ramp: ice-blue (slow) → sky → amber → orange → red (fast)
enum SpeedColorRamp {
    private static let stops: [(t: Double, r: Double, g: Double, b: Double)] = [
        (0.00, 0xBF / 255.0, 0xDB / 255.0, 0xFE / 255.0),  // #BFDBFE ice-blue
        (0.25, 0x60 / 255.0, 0xA5 / 255.0, 0xFA / 255.0),  // #60A5FA sky
        (0.50, 0xFB / 255.0, 0xBF / 255.0, 0x24 / 255.0),  // #FBBF24 amber
        (0.75, 0xF9 / 255.0, 0x73 / 255.0, 0x16 / 255.0),  // #F97316 orange
        (1.00, 0xDC / 255.0, 0x26 / 255.0, 0x26 / 255.0),  // #DC2626 red
    ]

    static func color(for normalizedSpeed: Double) -> UIColor {
        let t = max(0, min(1, normalizedSpeed))
        guard let hiIdx = stops.firstIndex(where: { $0.t >= t }) else {
            let s = stops.last!
            return UIColor(red: s.r, green: s.g, blue: s.b, alpha: 1)
        }
        if hiIdx == 0 {
            let s = stops[0]
            return UIColor(red: s.r, green: s.g, blue: s.b, alpha: 1)
        }
        let lo = stops[hiIdx - 1]
        let hi = stops[hiIdx]
        let frac = (t - lo.t) / (hi.t - lo.t)
        return UIColor(
            red:   lo.r + (hi.r - lo.r) * frac,
            green: lo.g + (hi.g - lo.g) * frac,
            blue:  lo.b + (hi.b - lo.b) * frac,
            alpha: 1
        )
    }
}
