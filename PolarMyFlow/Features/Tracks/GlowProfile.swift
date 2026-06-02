import Foundation

enum GlowProfile {
    private static let exponent = 1.2

    /// Pre-zoom blur radius factor in 4...20. The renderer divides this by `zoomScale`.
    /// Slow segments get a moderate visible halo; fast segments bloom large and bright.
    static func blurFactor(_ n: Double) -> Double {
        4.0 + 16.0 * pow(clamp(n), exponent)
    }

    /// Glow opacity in 0.30...0.95. Visible along the whole line, hottest on fast.
    static func alpha(_ n: Double) -> Double {
        0.30 + 0.65 * pow(clamp(n), exponent)
    }

    private static func clamp(_ n: Double) -> Double { max(0, min(1, n)) }
}
