import XCTest
import UIKit
@testable import PolarMyFlow

final class SpeedColorRampTests: XCTestCase {
    private func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    func testColorAtZero_isDeepBlue() {
        let c = components(SpeedColorRamp.color(for: 0.0))
        XCTAssertEqual(c.r, 0x25 / 255.0, accuracy: 0.01)  // #2563EB
        XCTAssertEqual(c.g, 0x63 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xEB / 255.0, accuracy: 0.01)
    }

    func testColorAtQuarter_isMediumBlue() {
        let c = components(SpeedColorRamp.color(for: 0.25))
        XCTAssertEqual(c.r, 0x3B / 255.0, accuracy: 0.01)  // #3B82F6
        XCTAssertEqual(c.g, 0x82 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xF6 / 255.0, accuracy: 0.01)
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

    func testColorBelowZero_clampsToDeepBlue() {
        let atZero = components(SpeedColorRamp.color(for: 0.0))
        let below  = components(SpeedColorRamp.color(for: -1.0))
        XCTAssertEqual(below.r, atZero.r, accuracy: 0.001)
        XCTAssertEqual(below.g, atZero.g, accuracy: 0.001)
        XCTAssertEqual(below.b, atZero.b, accuracy: 0.001)
    }

    func testColorAboveOne_clampsToRed() {
        let atOne = components(SpeedColorRamp.color(for: 1.0))
        let above = components(SpeedColorRamp.color(for: 2.0))
        XCTAssertEqual(above.r, atOne.r, accuracy: 0.001)
        XCTAssertEqual(above.g, atOne.g, accuracy: 0.001)
    }

    func testMidpointInterpolation_isBetweenStops() {
        // t=0.125 is halfway between deep blue (0.0) and medium blue (0.25)
        let c = components(SpeedColorRamp.color(for: 0.125))
        let deepBlueR = 0x25 / 255.0 as CGFloat
        let mediumBlueR = 0x3B / 255.0 as CGFloat
        let expected = (deepBlueR + mediumBlueR) / 2
        XCTAssertEqual(c.r, expected, accuracy: 0.01)
    }
}
