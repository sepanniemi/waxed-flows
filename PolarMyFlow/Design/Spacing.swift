import SwiftUI

/// Layout constants used across the screen scaffolding.
/// Per-component metrics (card padding, row gaps) stay literals inside
/// the component file — only screen-level repeats live here.
enum Spacing {
    /// Horizontal margin from the screen edge to content (cards, headers, rows).
    static let screenMargin: CGFloat = 20
    /// Top inset above the meta header on a screen rooted in `.polarBackground()`.
    static let screenTop: CGFloat = 48
}
