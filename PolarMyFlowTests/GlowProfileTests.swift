import XCTest
@testable import PolarMyFlow

final class GlowProfileTests: XCTestCase {
    func testBlurFactorEndpoints() {
        XCTAssertEqual(GlowProfile.blurFactor(0), 4.0,  accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.blurFactor(1), 20.0, accuracy: 1e-9)
    }

    func testAlphaEndpoints() {
        XCTAssertEqual(GlowProfile.alpha(0), 0.30, accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(1), 0.95, accuracy: 1e-9)
    }

    func testMonotonicInSpeed() {
        XCTAssertLessThan(GlowProfile.blurFactor(0.25), GlowProfile.blurFactor(0.75))
        XCTAssertLessThan(GlowProfile.alpha(0.25),      GlowProfile.alpha(0.75))
    }

    func testClampsOutOfRange() {
        XCTAssertEqual(GlowProfile.blurFactor(-1), GlowProfile.blurFactor(0), accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.blurFactor(2),  GlowProfile.blurFactor(1), accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(-1),      GlowProfile.alpha(0),      accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(2),       GlowProfile.alpha(1),      accuracy: 1e-9)
    }
}
