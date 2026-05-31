/// Builds a percentile-based normalizer mapping a speed (km/h) to 0...1 for the
/// color ramp. The median anchors at 0.5; the scale stretches across the
/// p10→p90 span but never tighter than `minSpan`, so a steady effort stays near
/// amber instead of being blown into a false rainbow. Fewer than two samples →
/// a constant 0.5.
enum SpeedNormalizer {
    static let minSpan = 3.0   // km/h

    static func make(from speeds: [Double]) -> (Double) -> Double {
        guard speeds.count >= 2 else { return { _ in 0.5 } }
        let sorted = speeds.sorted()
        func pct(_ p: Double) -> Double {
            let idx = Int((p * Double(sorted.count - 1)).rounded())
            return sorted[max(0, min(sorted.count - 1, idx))]
        }
        let p10 = pct(0.10), p50 = pct(0.50), p90 = pct(0.90)
        let half = max((p90 - p10) / 2.0, minSpan / 2.0)
        return { speed in max(0, min(1, 0.5 + 0.5 * (speed - p50) / half)) }
    }
}
