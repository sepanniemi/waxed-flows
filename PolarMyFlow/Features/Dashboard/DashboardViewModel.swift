import Foundation
import SwiftData

struct SportSummary: Identifiable {
    var id: SportType { sport }
    let sport: SportType
    let totalDistance: Double      // metres
    let totalDuration: TimeInterval
    let sessionCount: Int
    let avgPace: Double            // s/m
}

struct SeasonSummary: Identifiable {
    var id: Season { season }
    let season: Season
    let sportSummaries: [SportSummary]
}

@Observable
final class DashboardViewModel {
    private(set) var seasons: [SeasonSummary] = []
    private(set) var isLoading = false
    private let repository: ActivityRepository

    init(repository: ActivityRepository) {
        self.repository = repository
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let activities = try? repository.fetchAll() else { return }

        // Group activities by season
        var bySeason: [Season: [Activity]] = [:]
        for activity in activities {
            let season = Season.containing(activity.startTime)
            bySeason[season, default: []].append(activity)
        }

        seasons = bySeason
            .map { season, acts in
                SeasonSummary(season: season, sportSummaries: buildSportSummaries(acts))
            }
            .sorted { $0.season > $1.season }  // newest first
    }

    private func buildSportSummaries(_ activities: [Activity]) -> [SportSummary] {
        var bySport: [SportType: [Activity]] = [:]
        for act in activities {
            bySport[act.sportType, default: []].append(act)
        }
        return bySport.map { sport, acts in
            let totalDistance = acts.reduce(0) { $0 + $1.distance }
            let totalDuration = acts.reduce(0) { $0 + $1.duration }
            let avgPace = totalDistance > 0 ? totalDuration / totalDistance : 0
            return SportSummary(
                sport: sport,
                totalDistance: totalDistance,
                totalDuration: totalDuration,
                sessionCount: acts.count,
                avgPace: avgPace
            )
        }
        .sorted { $0.totalDistance > $1.totalDistance }
    }
}
