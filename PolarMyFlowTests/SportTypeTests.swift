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

    func test_symbolName_xcSkiing() {
        XCTAssertEqual(SportType.xcSkiing.symbolName, "figure.skiing.crosscountry")
    }

    func test_symbolName_other_isValid() {
        for sport in SportType.allCases {
            XCTAssertFalse(sport.symbolName.isEmpty, "\(sport) has empty symbolName")
        }
    }
}
