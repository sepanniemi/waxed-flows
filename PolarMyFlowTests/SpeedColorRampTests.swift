import XCTest
import UIKit
@testable import PolarMyFlow

final class SpeedColorRampTests: XCTestCase {
    private func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    func testColorAtZero_isIndigo() {
        let c = components(SpeedColorRamp.color(for: 0.0))
        XCTAssertEqual(c.r, 0x4F / 255.0, accuracy: 0.01)  // #4F46E5
        XCTAssertEqual(c.g, 0x46 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xE5 / 255.0, accuracy: 0.01)
    }

    func testColorAtQuarter_isPurple() {
        let c = components(SpeedColorRamp.color(for: 0.25))
        XCTAssertEqual(c.r, 0xA8 / 255.0, accuracy: 0.01)  // #A855F7
        XCTAssertEqual(c.g, 0x55 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0xF7 / 255.0, accuracy: 0.01)
    }

    func testColorAtHalf_isPink() {
        let c = components(SpeedColorRamp.color(for: 0.5))
        XCTAssertEqual(c.r, 0xEC / 255.0, accuracy: 0.01)  // #EC4899
        XCTAssertEqual(c.g, 0x48 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0x99 / 255.0, accuracy: 0.01)
    }

    func testColorAtOne_isOrange() {
        let c = components(SpeedColorRamp.color(for: 1.0))
        XCTAssertEqual(c.r, 0xF9 / 255.0, accuracy: 0.01)  // #F97316
        XCTAssertEqual(c.g, 0x73 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0x16 / 255.0, accuracy: 0.01)
    }

    func testColorBelowZero_clampsToIndigo() {
        let atZero = components(SpeedColorRamp.color(for: 0.0))
        let below  = components(SpeedColorRamp.color(for: -1.0))
        XCTAssertEqual(below.r, atZero.r, accuracy: 0.001)
        XCTAssertEqual(below.g, atZero.g, accuracy: 0.001)
        XCTAssertEqual(below.b, atZero.b, accuracy: 0.001)
    }

    func testColorAboveOne_clampsToOrange() {
        let atOne = components(SpeedColorRamp.color(for: 1.0))
        let above = components(SpeedColorRamp.color(for: 2.0))
        XCTAssertEqual(above.r, atOne.r, accuracy: 0.001)
        XCTAssertEqual(above.g, atOne.g, accuracy: 0.001)
        XCTAssertEqual(above.b, atOne.b, accuracy: 0.001)
    }

    func testMidpointInterpolation_isBetweenStops() {
        // t=0.125 is halfway between indigo (0.0) and purple (0.25)
        let c = components(SpeedColorRamp.color(for: 0.125))
        let indigoR = 0x4F / 255.0 as CGFloat
        let purpleR = 0xA8 / 255.0 as CGFloat
        let expected = (indigoR + purpleR) / 2
        XCTAssertEqual(c.r, expected, accuracy: 0.01)
    }
}
