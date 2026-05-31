import Foundation

/// Maps a normalized speed (0...1) to the track glow's pre-zoom blur factor and
/// alpha. Strong-contrast ramp: slow segments get a near-hairline, near-invisible
/// halo; fast segments bloom large and bright. The exponent makes the contrast
/// aggressive rather than linear.
enum GlowProfile {
    private static let exponent = 1.8

    /// Pre-zoom blur radius factor in 0.5...12. The renderer divides this by `zoomScale`.
    static func blurFactor(_ n: Double) -> Double {
        0.5 + 11.5 * pow(clamp(n), exponent)
    }

    /// Glow opacity in 0.12...0.90.
    static func alpha(_ n: Double) -> Double {
        0.12 + 0.78 * pow(clamp(n), exponent)
    }

    private static func clamp(_ n: Double) -> Double { max(0, min(1, n)) }
}
