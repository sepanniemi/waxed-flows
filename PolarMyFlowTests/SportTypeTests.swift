import XCTest
@testable import PolarMyFlow

final class SportTypeTests: XCTestCase {

    func test_knownSport_xcSkiing() {
        XCTAssertEqual(SportType(polarString: "CROSS_COUNTRY_SKIING"), .xcSkiing)
    }

    func test_knownSport_running() {
        XCTAssertEqual(SportType(polarString: "RUNNING"), .running)
    }

    func test_knownSport_cycling() {
        XCTAssertEqual(SportType(polarString: "CYCLING"), .cycling)
    }

    func test_knownSport_swimming() {
        XCTAssertEqual(SportType(polarString: "SWIMMING"), .swimming)
    }

    func test_unknownSport_fallsBackToOther() {
        XCTAssertEqual(SportType(polarString: "UNDERWATER_HOCKEY"), .other)
        XCTAssertEqual(SportType(polarString: ""), .other)
    }

    func test_displayName_xcSkiing() {
        XCTAssertEqual(SportType.xcSkiing.displayName, "XC Skiing")
    }

    func test_iconName_xcSkiing() {
        XCTAssertEqual(SportType.xcSkiing.iconName, "sport-xc-skiing")
    }

    func test_iconName_allCasesNonEmpty() {
        for sport in SportType.allCases {
            XCTAssertFalse(sport.iconName.isEmpty, "\(sport) has empty iconName")
        }
    }

    func test_dotColor_allCasesDefined() {
        // Compile-time guarantee — switch exhaustiveness enforces this.
        for sport in SportType.allCases {
            _ = sport.dotColor
        }
    }
}
