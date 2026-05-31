import XCTest
@testable import PolarMyFlow

final class SpeedInterpolatorTests: XCTestCase {
    func testInteriorGapInterpolates() {
        XCTAssertEqual(SpeedInterpolator.fill([10, nil, 20]), [10, 15, 20])
    }

    func testLeadingGapTakesFirstKnown() {
        XCTAssertEqual(SpeedInterpolator.fill([nil, nil, 12]), [12, 12, 12])
    }

    func testTrailingGapTakesLastKnown() {
        XCTAssertEqual(SpeedInterpolator.fill([12, nil, nil]), [12, 12, 12])
    }

    func testAllNilReturnsEmpty() {
        XCTAssertEqual(SpeedInterpolator.fill([nil, nil]), [])
    }

    func testEmptyReturnsEmpty() {
        XCTAssertEqual(SpeedInterpolator.fill([]), [])
    }

    func testSingleElement() {
        XCTAssertEqual(SpeedInterpolator.fill([7.0]), [7.0])
    }

    func testNoNilPassthrough() {
        XCTAssertEqual(SpeedInterpolator.fill([5, 6, 7]), [5, 6, 7])
    }

    func testCombinedLeadingInteriorTrailing() {
        XCTAssertEqual(SpeedInterpolator.fill([nil, 10, nil, nil, 40, nil]),
                       [10, 10, 20, 30, 40, 40])
    }
}
