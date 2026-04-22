import XCTest
import SwiftUI
@testable import PolarMyFlow

final class PaletteTests: XCTestCase {
    func test_polarNight_matchesSpecHex() {
        XCTAssertEqual(Palette.polarNight.hexString, "#0A1428")
    }
    func test_polarSky_matchesSpecHex() {
        XCTAssertEqual(Palette.polarSky.hexString, "#60A5FA")
    }
    func test_polarAmber_matchesSpecHex() {
        XCTAssertEqual(Palette.polarAmber.hexString, "#FBBF24")
    }
    func test_allTokensExist() {
        // If this compiles, all tokens are defined.
        _ = Palette.polarNight
        _ = Palette.polarDeep
        _ = Palette.polarRoyal
        _ = Palette.polarSky
        _ = Palette.polarSkyLight
        _ = Palette.polarSkyIce
        _ = Palette.polarAmber
        _ = Palette.ink
        _ = Palette.inkMuted
        _ = Palette.inkFaint
        _ = Palette.surfaceGlass
        _ = Palette.surfaceBorder
        _ = Palette.ruleSoft
    }
}

// Test helper — converts SwiftUI Color back to hex for assertion.
private extension Color {
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(round(r * 255)),
                      Int(round(g * 255)),
                      Int(round(b * 255)))
    }
}
