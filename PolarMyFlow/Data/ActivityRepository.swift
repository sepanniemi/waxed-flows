import Foundation
import SwiftData

final class ActivityRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // Insert only if ID not already present (deduplication)
    func save(_ activity: Activity) throws {
        let id = activity.id
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.id == id }
        )
        let existing = try context.fetch(descriptor)
        guard existing.isEmpty else { return }
        context.insert(activity)
        try context.save()
    }

    func fetchAll() throws -> [Activity] {
        let descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(sport: SportType) throws -> [Activity] {
        let raw = sport.rawValue
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.sportRawValue == raw },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(in range: Range<Date>) throws -> [Activity] {
        let start = range.lowerBound
        let end   = range.upperBound
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.startTime >= start && $0.startTime < end },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(sport: SportType, in range: Range<Date>) throws -> [Activity] {
        let raw   = sport.rawValue
        let start = range.lowerBound
        let end   = range.upperBound
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate {
                $0.sportRawValue == raw &&
                $0.startTime >= start &&
                $0.startTime < end
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func availableSports() throws -> [SportType] {
        let all = try fetchAll()
        let unique = Set(all.map { SportType(polarString: $0.sportRawValue) })
        return unique.sorted { $0.displayName < $1.displayName }
    }

    // Returns existing SyncState for user, or creates and saves a new one
    func syncState(forUserID userID: String) throws -> SyncState {
        let descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { $0.userID == userID }
        )
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let state = SyncState(userID: userID)
        context.insert(state)
        try context.save()
        return state
    }

    func saveSyncState() throws {
        try context.save()
    }
}
