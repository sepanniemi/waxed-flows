import Foundation
import SwiftData
@testable import PolarMyFlow

func makeTestContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Activity.self, SyncState.self,
        configurations: config
    )
    return ModelContext(container)
}

func makeActivity(
    id: String = "act-1",
    startTime: Date = Date(),
    duration: TimeInterval = 3600,
    distance: Double = 10000,
    sport: String = "RUNNING",
    avgSpeed: Double = 2.78,
    avgPace: Double = 0.36
) -> Activity {
    Activity(
        id: id,
        startTime: startTime,
        duration: duration,
        distance: distance,
        sportRawValue: sport,
        avgSpeed: avgSpeed,
        avgPace: avgPace
    )
}

class InMemoryTokenStore: TokenStore {
    private var stored: AuthToken?

    func save(_ token: AuthToken) throws { stored = token }
    func load() throws -> AuthToken? { stored }
    func delete() throws { stored = nil }
}
