import XCTest
@testable import PolarMyFlow

final class SeasonTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(year: Int, month: Int, day: Int = 1) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // Season classification
    func test_november_isWinter() {
        XCTAssertEqual(Season.containing(date(year: 2024, month: 11)), .winter(startYear: 2024))
    }

    func test_january_isWinter() {
        XCTAssertEqual(Season.containing(date(year: 2025, month: 1)), .winter(startYear: 2024))
    }

    func test_april_isWinter() {
        XCTAssertEqual(Season.containing(date(year: 2025, month: 4)), .winter(startYear: 2024))
    }

    func test_may_isSummer() {
        XCTAssertEqual(Season.containing(date(year: 2025, month: 5)), .summer(year: 2025))
    }

    func test_october_isSummer() {
        XCTAssertEqual(Season.containing(date(year: 2024, month: 10)), .summer(year: 2024))
    }

    // Labels
    func test_winterLabel() {
        XCTAssertEqual(Season.winter(startYear: 2024).label, "Winter 2024–25")
    }

    func test_summerLabel() {
        XCTAssertEqual(Season.summer(year: 2025).label, "Summer 2025")
    }

    // Date range
    func test_winterDateRange_2024() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        let season = Season.winter(startYear: 2024)
        let range = season.dateRange
        XCTAssertEqual(c.component(.month, from: range.lowerBound), 11)
        XCTAssertEqual(c.component(.year, from: range.lowerBound), 2024)
        XCTAssertEqual(c.component(.month, from: range.upperBound), 5)
        XCTAssertEqual(c.component(.year, from: range.upperBound), 2025)
    }

    func test_summerDateRange_2024() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        let season = Season.summer(year: 2024)
        let range = season.dateRange
        XCTAssertEqual(c.component(.month, from: range.lowerBound), 5)
        XCTAssertEqual(c.component(.month, from: range.upperBound), 11)
        XCTAssertEqual(c.component(.year, from: range.lowerBound), 2024)
    }

    // Sorting
    func test_olderSeasonSortsFirst() {
        let w2023 = Season.winter(startYear: 2023)
        let w2024 = Season.winter(startYear: 2024)
        XCTAssertLessThan(w2023, w2024)
    }
}
