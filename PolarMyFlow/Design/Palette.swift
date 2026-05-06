import SwiftUI

enum Palette {
    static let polarNight   = Color(red: 0x0A / 255, green: 0x14 / 255, blue: 0x28 / 255)
    static let polarDeep    = Color(red: 0x14 / 255, green: 0x24 / 255, blue: 0x51 / 255)
    static let polarRoyal   = Color(red: 0x1E / 255, green: 0x3A / 255, blue: 0x8A / 255)
    static let polarSky     = Color(red: 0x60 / 255, green: 0xA5 / 255, blue: 0xFA / 255)
    static let polarSkyLight = Color(red: 0x93 / 255, green: 0xC5 / 255, blue: 0xFD / 255)
    static let polarSkyIce  = Color(red: 0xBF / 255, green: 0xDB / 255, blue: 0xFE / 255)
    static let polarAmber   = Color(red: 0xFB / 255, green: 0xBF / 255, blue: 0x24 / 255)

    static let ink       = Color.white
    static let inkMuted  = Color.white.opacity(0.70)
    static let inkFaint  = Color.white.opacity(0.45)

    static let surfaceGlass  = Color.white.opacity(0.04)
    static let surfaceBorder = Color.white.opacity(0.08)
    static let ruleSoft      = Color.white.opacity(0.14)

    /// Semantic alias — destructive / caution actions (sign out, delete).
    static let destructive   = polarAmber
}
