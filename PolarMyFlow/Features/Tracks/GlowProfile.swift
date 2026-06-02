import Foundation

enum GlowProfile {
    private static let exponent = 1.2

    /// Pre-zoom blur radius factor in 8...32. The renderer divides this by `zoomScale`.
    /// Slow segments get a noticeable halo; fast segments bloom large and bright.
    static func blurFactor(_ n: Double) -> Double {
        8.0 + 24.0 * pow(clamp(n), exponent)
    }

    /// Glow opacity in 0.45...1.0. Clearly visible along the whole line, hottest on fast.
    static func alpha(_ n: Double) -> Double {
        0.45 + 0.55 * pow(clamp(n), exponent)
    }

    private static func clamp(_ n: Double) -> Double { max(0, min(1, n)) }
}
