import XCTest
@testable import PolarMyFlow

final class GlowProfileTests: XCTestCase {
    func testBlurFactorEndpoints() {
        XCTAssertEqual(GlowProfile.blurFactor(0), 0.5, accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.blurFactor(1), 12.0, accuracy: 1e-9)
    }

    func testAlphaEndpoints() {
        XCTAssertEqual(GlowProfile.alpha(0), 0.12, accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(1), 0.90, accuracy: 1e-9)
    }

    func testMonotonicInSpeed() {
        XCTAssertLessThan(GlowProfile.blurFactor(0.25), GlowProfile.blurFactor(0.75))
        XCTAssertLessThan(GlowProfile.alpha(0.25), GlowProfile.alpha(0.75))
    }

    func testClampsOutOfRange() {
        XCTAssertEqual(GlowProfile.blurFactor(-1), GlowProfile.blurFactor(0), accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.blurFactor(2),  GlowProfile.blurFactor(1), accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(-1),      GlowProfile.alpha(0),      accuracy: 1e-9)
        XCTAssertEqual(GlowProfile.alpha(2),       GlowProfile.alpha(1),      accuracy: 1e-9)
    }
}
