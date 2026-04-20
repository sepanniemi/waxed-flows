import XCTest
@testable import PolarMyFlow

final class ActivityDetailViewModelTests: XCTestCase {

    func test_durationString_hoursMinutesSeconds() {
        let vm = makeVM(duration: 3_661)
        XCTAssertEqual(vm.durationString, "1:01:01")
    }

    func test_durationString_minutesSeconds() {
        let vm = makeVM(duration: 125)
        XCTAssertEqual(vm.durationString, "2:05")
    }

    func test_distanceString_kmWithTwoDecimals() {
        let vm = makeVM(distance: 12_345)
        XCTAssertEqual(vm.distanceString, "12.35 km")
    }

    func test_paceString_minPerKm() {
        // 0.3 s/m → 300 s/km → 5:00 /km
        let vm = makeVM(avgPace: 0.3)
        XCTAssertEqual(vm.paceString, "5:00 /km")
    }

    func test_heartRateStrings_optional() {
        let none = makeVM(avgHR: nil, maxHR: nil)
        XCTAssertNil(none.avgHRString)
        XCTAssertNil(none.maxHRString)

        let both = makeVM(avgHR: 140, maxHR: 170)
        XCTAssertEqual(both.avgHRString, "140 bpm")
        XCTAssertEqual(both.maxHRString, "170 bpm")
    }

    func test_elevationStrings_optional() {
        let none = makeVM(ascent: nil, descent: nil)
        XCTAssertNil(none.ascentString)
        XCTAssertNil(none.descentString)

        let both = makeVM(ascent: 123.4, descent: 98.6)
        XCTAssertEqual(both.ascentString, "↑ 123 m")
        XCTAssertEqual(both.descentString, "↓ 99 m")
    }

    func test_caloriesString_optional() {
        XCTAssertNil(makeVM(calories: nil).caloriesString)
        XCTAssertEqual(makeVM(calories: 512).caloriesString, "512 kcal")
    }

    func test_title_usesSportDisplayName() {
        let vm = makeVM(sport: "CROSS_COUNTRY_SKIING")
        XCTAssertEqual(vm.title, "XC Skiing")
    }

    private func makeVM(
        sport: String = "RUNNING",
        duration: TimeInterval = 3600,
        distance: Double = 10_000,
        avgPace: Double = 0.36,
        avgHR: Int? = nil,
        maxHR: Int? = nil,
        ascent: Double? = nil,
        descent: Double? = nil,
        calories: Int? = nil
    ) -> ActivityDetailViewModel {
        let activity = Activity(
            id: "t",
            startTime: Date(),
            duration: duration,
            distance: distance,
            sportRawValue: sport,
            avgSpeed: distance > 0 ? distance / duration : 0,
            avgPace: avgPace,
            avgHeartRate: avgHR,
            maxHeartRate: maxHR,
            ascent: ascent,
            descent: descent,
            calories: calories,
            hasRoute: false
        )
        return ActivityDetailViewModel(activity: activity)
    }
}
