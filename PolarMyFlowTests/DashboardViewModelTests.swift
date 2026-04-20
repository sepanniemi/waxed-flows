import XCTest
import SwiftData
@testable import PolarMyFlow

@MainActor
final class DashboardViewModelTests: XCTestCase {
    var context: ModelContext!
    var repo: ActivityRepository!
    var vm: DashboardViewModel!

    override func setUpWithError() throws {
        context = try makeTestContext()
        repo = ActivityRepository(context: context)
        vm = DashboardViewModel(repository: repo)
    }

    func test_load_emptyDB_yieldsNoSeasons() async {
        await vm.load()
        XCTAssertTrue(vm.seasons.isEmpty)
    }

    func test_load_groupsBySeasonAndSport() async throws {
        let cal = gregorianUTC()
        let janWinter = cal.date(from: DateComponents(year: 2025, month: 1, day: 10))!
        let junSummer = cal.date(from: DateComponents(year: 2025, month: 6, day: 10))!

        try repo.save(makeActivity(id: "run1", startTime: janWinter, distance: 10_000, sport: "RUNNING"))
        try repo.save(makeActivity(id: "run2", startTime: janWinter, distance: 5_000, sport: "RUNNING"))
        try repo.save(makeActivity(id: "ski1", startTime: janWinter, distance: 20_000, sport: "CROSS_COUNTRY_SKIING"))
        try repo.save(makeActivity(id: "bike1", startTime: junSummer, distance: 40_000, sport: "CYCLING"))

        await vm.load()

        XCTAssertEqual(vm.seasons.count, 2)
        // Newest first
        XCTAssertEqual(vm.seasons[0].season, .summer(year: 2025))
        XCTAssertEqual(vm.seasons[1].season, .winter(startYear: 2024))

        let winter = vm.seasons[1]
        // Sport summaries sorted by totalDistance desc: ski (20km) then running (15km)
        XCTAssertEqual(winter.sportSummaries.map(\.sport), [.xcSkiing, .running])
        let running = winter.sportSummaries.first { $0.sport == .running }!
        XCTAssertEqual(running.sessionCount, 2)
        XCTAssertEqual(running.totalDistance, 15_000)
    }

    func test_load_avgPace_isDurationOverTotalDistance() async throws {
        let cal = gregorianUTC()
        let when = cal.date(from: DateComponents(year: 2025, month: 6, day: 1))!
        try repo.save(makeActivity(id: "a", startTime: when, duration: 3600, distance: 10_000, sport: "RUNNING"))
        try repo.save(makeActivity(id: "b", startTime: when, duration: 1800, distance: 5_000, sport: "RUNNING"))

        await vm.load()

        let running = vm.seasons[0].sportSummaries.first { $0.sport == .running }!
        // total 5400s / 15000m = 0.36 s/m
        XCTAssertEqual(running.avgPace, 0.36, accuracy: 0.0001)
    }

    func test_load_zeroDistance_avgPaceIsZero() async throws {
        let cal = gregorianUTC()
        let when = cal.date(from: DateComponents(year: 2025, month: 6, day: 1))!
        try repo.save(makeActivity(id: "s1", startTime: when, duration: 3600, distance: 0, sport: "STRENGTH_TRAINING"))

        await vm.load()

        let strength = vm.seasons[0].sportSummaries.first { $0.sport == .strength }!
        XCTAssertEqual(strength.avgPace, 0)
    }

    private func gregorianUTC() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
}
