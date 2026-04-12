import XCTest
import SwiftData
@testable import PolarMyFlow

final class ActivityRepositoryTests: XCTestCase {
    var context: ModelContext!
    var repo: ActivityRepository!

    override func setUpWithError() throws {
        context = try makeTestContext()
        repo = ActivityRepository(context: context)
    }

    func test_save_insertsActivity() throws {
        let act = makeActivity(id: "a1")
        try repo.save(act)
        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, "a1")
    }

    func test_save_deduplicatesByID() throws {
        let act1 = makeActivity(id: "a1", distance: 5000)
        let act2 = makeActivity(id: "a1", distance: 9000)
        try repo.save(act1)
        try repo.save(act2)  // same id — should not insert again
        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.distance, 5000)  // original preserved
    }

    func test_fetchBySport_filtersCorrectly() throws {
        try repo.save(makeActivity(id: "r1", sport: "RUNNING"))
        try repo.save(makeActivity(id: "s1", sport: "CROSS_COUNTRY_SKIING"))
        let runners = try repo.fetch(sport: .running)
        XCTAssertEqual(runners.count, 1)
        XCTAssertEqual(runners.first?.id, "r1")
    }

    func test_fetchByDateRange_filtersCorrectly() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let jan = cal.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let mar = cal.date(from: DateComponents(year: 2025, month: 3, day: 15))!
        let jun = cal.date(from: DateComponents(year: 2025, month: 6, day: 15))!

        try repo.save(makeActivity(id: "jan", startTime: jan))
        try repo.save(makeActivity(id: "mar", startTime: mar))
        try repo.save(makeActivity(id: "jun", startTime: jun))

        let winterRange = Season.winter(startYear: 2024).dateRange
        let winterActs = try repo.fetch(in: winterRange)
        XCTAssertEqual(winterActs.count, 2)
        XCTAssertTrue(winterActs.map(\.id).contains("jan"))
        XCTAssertTrue(winterActs.map(\.id).contains("mar"))
    }

    func test_availableSports_returnsOnlySportsWithActivities() throws {
        try repo.save(makeActivity(id: "r1", sport: "RUNNING"))
        try repo.save(makeActivity(id: "r2", sport: "RUNNING"))
        try repo.save(makeActivity(id: "s1", sport: "CROSS_COUNTRY_SKIING"))
        let sports = try repo.availableSports()
        XCTAssertEqual(Set(sports), [.running, .xcSkiing])
    }

    func test_syncState_createdIfAbsent() throws {
        let state = try repo.syncState(forUserID: "user-1")
        XCTAssertEqual(state.userID, "user-1")
        XCTAssertFalse(state.accessLinkRegistered)
        XCTAssertFalse(state.historicalImportComplete)
    }

    func test_syncState_returnsSameInstance() throws {
        let s1 = try repo.syncState(forUserID: "user-1")
        s1.accessLinkRegistered = true
        try context.save()
        let s2 = try repo.syncState(forUserID: "user-1")
        XCTAssertTrue(s2.accessLinkRegistered)
    }
}
