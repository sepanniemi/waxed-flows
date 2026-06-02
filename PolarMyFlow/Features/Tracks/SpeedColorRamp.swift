import UIKit

// A4 colour ramp: indigo (slow) → purple → pink → red → orange (fast)
// Chosen for contrast on Maastokartta topo tiles — avoids blue (clashes with water)
// and amber/yellow (invisible on cream land fill) that were present in earlier ramps.
enum SpeedColorRamp {
    private static let stops: [(t: Double, r: Double, g: Double, b: Double)] = [
        (0.00, 0x4F / 255.0, 0x46 / 255.0, 0xE5 / 255.0),  // #4F46E5 indigo   (slow)
        (0.25, 0xA8 / 255.0, 0x55 / 255.0, 0xF7 / 255.0),  // #A855F7 purple
        (0.50, 0xEC / 255.0, 0x48 / 255.0, 0x99 / 255.0),  // #EC4899 pink
        (0.75, 0xEF / 255.0, 0x44 / 255.0, 0x44 / 255.0),  // #EF4444 red
        (1.00, 0xF9 / 255.0, 0x73 / 255.0, 0x16 / 255.0),  // #F97316 orange   (fast)
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
