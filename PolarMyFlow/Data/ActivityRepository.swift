import Foundation
import SwiftData

final class ActivityRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // Insert if no record exists by ID or by start-time minute bucket. If a
    // duplicate exists and the incoming record carries GPS the existing one
    // lacks, merge it in — covers both re-syncing an existing AccessLink
    // exercise (same ID, GPX now available) and AccessLink supplying a route
    // for a GDPR-imported activity (different ID, same minute).
    func save(_ activity: Activity) throws {
        let id = activity.id
        let byID = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(byID).first {
            try mergeGPSIfBetter(into: existing, from: activity)
            return
        }

        let bucketStart = Self.minuteBucket(activity.startTime)
        let bucketEnd = bucketStart.addingTimeInterval(60)
        let byTime = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.startTime >= bucketStart && $0.startTime < bucketEnd }
        )
        if let existing = try context.fetch(byTime).first {
            try mergeGPSIfBetter(into: existing, from: activity)
            return
        }

        context.insert(activity)
        try context.save()
    }

    private func mergeGPSIfBetter(into existing: Activity, from incoming: Activity) throws {
        guard existing.routePointsData == nil, let data = incoming.routePointsData else { return }
        existing.routePointsData = data
        existing.hasRoute = true
        try context.save()
    }

    static func minuteBucket(_ date: Date) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return cal.date(from: comps) ?? date
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
