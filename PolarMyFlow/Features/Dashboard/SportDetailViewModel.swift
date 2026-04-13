import Foundation
import SwiftData

@Observable
final class SportDetailViewModel {
    private(set) var activities: [Activity] = []
    let sport: SportType
    let season: Season
    var startDate: Date
    var endDate: Date
    private let repository: ActivityRepository

    init(sport: SportType, season: Season, repository: ActivityRepository) {
        self.sport = sport
        self.season = season
        self.repository = repository
        self.startDate = season.dateRange.lowerBound
        self.endDate = season.dateRange.upperBound
    }

    var totalDistance: String {
        let km = activities.reduce(0) { $0 + $1.distance } / 1000
        return String(format: "%.1f km", km)
    }

    var sessionCount: String { "\(activities.count) sessions" }

    @MainActor
    func load() async {
        let range = startDate..<endDate
        activities = (try? repository.fetch(sport: sport, in: range)) ?? []
    }
}
