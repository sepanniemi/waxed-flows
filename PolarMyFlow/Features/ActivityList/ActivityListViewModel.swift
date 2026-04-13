import Foundation
import SwiftData

@Observable
final class ActivityListViewModel {
    private(set) var activities: [Activity] = []
    private(set) var availableSports: [SportType] = []
    var selectedSport: SportType? = nil {
        didSet { Task { await load() } }
    }
    private let repository: ActivityRepository

    init(repository: ActivityRepository) {
        self.repository = repository
    }

    @MainActor
    func load() async {
        availableSports = (try? repository.availableSports()) ?? []
        if let sport = selectedSport {
            activities = (try? repository.fetch(sport: sport)) ?? []
        } else {
            activities = (try? repository.fetchAll()) ?? []
        }
    }
}
