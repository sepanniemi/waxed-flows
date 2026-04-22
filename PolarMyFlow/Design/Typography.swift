import SwiftUI

extension Font {
    // Display face — Anton, condensed, uppercase
    static let displayJumbo  = Font.custom("Anton-Regular", size: 86)
    static let displayLarge  = Font.custom("Anton-Regular", size: 42)
    static let displayMedium = Font.custom("Anton-Regular", size: 34)
    static let displaySmall  = Font.custom("Anton-Regular", size: 26)
    static let displayTab    = Font.custom("Anton-Regular", size: 14)

    // Meta — SF Mono, uppercase, wide tracking (caller applies .tracking/.textCase)
    static let metaDefault = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let metaSmall   = Font.system(size:  9, weight: .medium, design: .monospaced)

    // Body — SF Pro Text
    static let bodyDefault = Font.system(size: 13, weight: .regular)
    static let bodyCaption = Font.system(size: 11, weight: .regular)
}

/// Common meta-label styling: uppercase, tracked, faint ink.
struct MetaLabel: ViewModifier {
    var size: Font = .metaDefault
    var color: Color = Palette.inkFaint
    func body(content: Content) -> some View {
        content
            .font(size)
            .tracking(1.8)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    func metaLabel(_ size: Font = .metaDefault, color: Color = Palette.inkFaint) -> some View {
        modifier(MetaLabel(size: size, color: color))
    }
}

/// Display text with the 2pt offset shadow in polarNight at 90% alpha.
struct DisplayShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: Palette.polarNight.opacity(0.9), radius: 0, x: 2, y: 2)
    }
}

extension View {
    func displayShadow() -> some View { modifier(DisplayShadow()) }
}
