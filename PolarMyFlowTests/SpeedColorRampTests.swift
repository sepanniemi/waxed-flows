import XCTest
import UIKit
@testable import PolarMyFlow

final class SpeedColorRampTests: XCTestCase {
    private func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    func testColorAtZero_isIceBlue() {
        let c = components(SpeedColorRamp.color(for: 0.0))
        XCTAssertEqual(c.r, 0xBF / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0xDB / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xFE / 255.0, accuracy: 0.01)
    }

    func testColorAtQuarter_isSky() {
        let c = components(SpeedColorRamp.color(for: 0.25))
        XCTAssertEqual(c.r, 0x60 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0xA5 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xFA / 255.0, accuracy: 0.01)
    }

    func testColorAtHalf_isAmber() {
        let c = components(SpeedColorRamp.color(for: 0.5))
        XCTAssertEqual(c.r, 0xFB / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0xBF / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0x24 / 255.0, accuracy: 0.01)
    }

    func testColorAtOne_isRed() {
        let c = components(SpeedColorRamp.color(for: 1.0))
        XCTAssertEqual(c.r, 0xDC / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0x26 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0x26 / 255.0, accuracy: 0.01)
    }

    func testColorBelowZero_clampsToIceBlue() {
        let atZero = components(SpeedColorRamp.color(for: 0.0))
        let below  = components(SpeedColorRamp.color(for: -1.0))
        XCTAssertEqual(below.r, atZero.r, accuracy: 0.001)
        XCTAssertEqual(below.g, atZero.g, accuracy: 0.001)
    }

    func testColorAboveOne_clampsToRed() {
        let atOne = components(SpeedColorRamp.color(for: 1.0))
        let above = components(SpeedColorRamp.color(for: 2.0))
        XCTAssertEqual(above.r, atOne.r, accuracy: 0.001)
        XCTAssertEqual(above.g, atOne.g, accuracy: 0.001)
    }

    func testMidpointInterpolation_isBetweenStops() {
        // t=0.125 is halfway between ice-blue (0.0) and sky (0.25)
        let c = components(SpeedColorRamp.color(for: 0.125))
        let iceBlueR = 0xBF / 255.0 as CGFloat
        let skyR = 0x60 / 255.0 as CGFloat
        let expected = (iceBlueR + skyR) / 2
        XCTAssertEqual(c.r, expected, accuracy: 0.01)
    }
}
