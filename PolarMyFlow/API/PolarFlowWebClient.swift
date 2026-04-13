import Foundation
import WebKit

// MARK: - Decodable types

struct Session: Decodable {
    let id: Int64
    let duration: Double        // milliseconds
    let distance: Double?       // metres, nullable
    let hrAvg: Int?
    let calories: Int?
    let sportId: Int
    let startDate: String       // "yyyy-MM-dd HH:mm:ss.SSS"
}

struct ActivitySummary: Decodable {
    let hrMax: Int?
    let exercises: [ExerciseSummary]?
}

struct ExerciseSummary: Decodable {
    let ascent: Double?
    let descent: Double?
}

// MARK: - Client

final class PolarFlowWebClient {
    private let session: URLSession
    private let userID: String
    private var cookieHeader: String?

    init(session: URLSession = .shared, userID: String, cookieHeader: String? = nil) {
        self.session = session
        self.userID = userID
        self.cookieHeader = cookieHeader
    }

    // Fetch cookies from the shared iOS web session (call after OAuth login)
    static func extractCookieHeader() async -> String? {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        let polarCookies = cookies.filter { $0.domain.contains("polar.com") }
        guard !polarCookies.isEmpty else { return nil }
        return polarCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    // Fetch all historical activities by requesting 1-year chunks.
    // Also fetches the summary endpoint per activity to enrich maxHR, ascent, descent.
    func fetchAllActivities() async throws -> [Activity] {
        var all: [Activity] = []
        let cal = Calendar(identifier: .gregorian)
        let currentYear = cal.component(.year, from: Date())
        let startYear = PolarFlowWebConstants.historyStartYear

        for year in startYear...currentYear {
            let fromDate = String(format: "%04d-01-01", year)
            let toDate   = year < currentYear
                ? String(format: "%04d-12-31", year)
                : dateString(Date())
            let batch = try await fetchChunk(from: fromDate, to: toDate)
            all.append(contentsOf: batch)
        }
        return all
    }

    // Exposed for testing: fetch a single date-range chunk (no summary enrichment)
    func fetchActivities(from: String, to: String) async throws -> [Activity] {
        try await fetchChunk(from: from, to: to, enrichWithSummary: false)
    }

    // MARK: - Private

    private func fetchChunk(from: String, to: String, enrichWithSummary: Bool = true) async throws -> [Activity] {
        let url = URL(string: PolarFlowWebConstants.baseURL + PolarFlowWebConstants.historyPath)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01",
                         forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        if let cookie = cookieHeader {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let body = ["userId": Int(userID) ?? 0, "fromDate": from, "toDate": to] as [String: Any]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkUnavailable }
        guard http.statusCode == 200 else { throw APIError.httpError(statusCode: http.statusCode) }

        let sessions = try parseSessions(from: data)
        var activities: [Activity] = []
        for s in sessions {
            let summary: ActivitySummary? = enrichWithSummary ? await fetchSummary(activityID: String(s.id)) : nil
            if let activity = buildActivity(from: s, summary: summary) {
                activities.append(activity)
            }
        }
        return activities
    }

    private func parseSessions(from data: Data) throws -> [Session] {
        guard let sessions = try? JSONDecoder().decode([Session].self, from: data) else {
            throw APIError.apiChanged("Unable to import history — Polar may have updated their API")
        }
        return sessions
    }

    private func buildActivity(from s: Session, summary: ActivitySummary?) -> Activity? {
        let formatter = DateFormatter()
        formatter.dateFormat = PolarFlowWebConstants.responseDateFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let startTime = formatter.date(from: s.startDate) else { return nil }
        let durationSecs = s.duration / 1000.0
        let dist = s.distance ?? 0.0
        let sport = SportType.from(polarSportId: s.sportId)
        let speed = dist > 0 ? dist / durationSecs : 0.0
        let pace  = dist > 0 ? durationSecs / dist : 0.0

        return Activity(
            id: String(s.id),
            startTime: startTime,
            duration: durationSecs,
            distance: dist,
            sportRawValue: sport.rawValue,
            avgSpeed: speed,
            avgPace: pace,
            avgHeartRate: s.hrAvg,
            maxHeartRate: summary?.hrMax,
            ascent: summary?.exercises?.first?.ascent,
            descent: summary?.exercises?.first?.descent,
            calories: s.calories,
            hasRoute: false
        )
    }

    // Fetch summary (maxHR, ascent, descent) for a single activity. Returns nil on failure.
    func fetchSummary(activityID: String) async -> ActivitySummary? {
        let path = String(format: PolarFlowWebConstants.summaryPath, activityID)
        guard let url = URL(string: PolarFlowWebConstants.baseURL + path) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        if let cookie = cookieHeader {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(ActivitySummary.self, from: data)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

protocol FlowWebClientProtocol {
    func fetchAllActivities() async throws -> [Activity]
}

extension PolarFlowWebClient: FlowWebClientProtocol {}
