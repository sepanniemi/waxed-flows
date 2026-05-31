import XCTest
@testable import PolarMyFlow

final class SpeedNormalizerTests: XCTestCase {
    func testFewerThanTwoIsConstantHalf() {
        let n0 = SpeedNormalizer.make(from: [])
        XCTAssertEqual(n0(99), 0.5, accuracy: 1e-9)
        let n1 = SpeedNormalizer.make(from: [5])
        XCTAssertEqual(n1(5),  0.5, accuracy: 1e-9)
        XCTAssertEqual(n1(50), 0.5, accuracy: 1e-9)
    }

    func testVariedInputSpansFullRamp() {
        // p10 = 2, p50 = 10, p90 = 18; half-span = 8 km/h.
        let speeds = [0.0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
        let n = SpeedNormalizer.make(from: speeds)
        XCTAssertEqual(n(10), 0.5, accuracy: 1e-9)   // p50 → amber
        XCTAssertEqual(n(18), 1.0, accuracy: 1e-9)   // p90 → red
        XCTAssertEqual(n(2),  0.0, accuracy: 1e-9)   // p10 → ice-blue
        XCTAssertEqual(n(0), 0.0, accuracy: 1e-9)   // below p10 → clamped to 0
    }

    func testFloorPreventsFalseContrastOnFlatEffort() {
        // All-equal speeds: real span is 0, so the 3 km/h minSpan floor governs.
        let n = SpeedNormalizer.make(from: [10.0, 10, 10, 10])
        XCTAssertEqual(n(10),    0.5,  accuracy: 1e-9)   // median stays amber
        XCTAssertEqual(n(10.75), 0.75, accuracy: 1e-9)   // mid-ramp, not saturated
        XCTAssertEqual(n(11.5),  1.0,  accuracy: 1e-9)   // a full half-span reaches the end
    }
}
