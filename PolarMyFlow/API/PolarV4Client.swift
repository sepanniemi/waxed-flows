import Foundation

final class PolarV4Client {
    private let urlSession: URLSession
    private let accessToken: String
    private static let baseURL = "https://www.polaraccesslink.com/v4/data"

    init(session: URLSession = .shared, accessToken: String) {
        self.urlSession = session
        self.accessToken = accessToken
    }

    // Internal for testing
    static func parseISO8601Duration(_ string: String) -> TimeInterval? {
        guard string.hasPrefix("PT") else { return nil }
        var remaining = String(string.dropFirst(2))
        var total: Double = 0
        for (unit, multiplier) in [("H", 3600.0), ("M", 60.0), ("S", 1.0)] {
            if let range = remaining.range(of: unit) {
                if let value = Double(remaining[remaining.startIndex..<range.lowerBound]) {
                    total += value * multiplier
                }
                remaining = String(remaining[range.upperBound...])
            }
        }
        return total > 0 ? total : nil
    }
}

// MARK: - AccessLinkClientProtocol

extension PolarV4Client: AccessLinkClientProtocol {
    func registerUser() async throws -> String {
        // v4 uses OAuth2 consent — no user registration step. Fixed key for SyncState.
        return "polar-v4"
    }

    func pullNewActivities(since: Date?) async throws -> [Activity] {
        let to = Date()
        let from = since ?? Calendar.current.date(byAdding: .day, value: -30, to: to)!
        let list = try await fetchSessionList(from: from, to: to)
        var activities: [Activity] = []
        for item in list {
            guard let session = try? await fetchSessionDetail(id: item.id),
                  let activity = session.toActivity() else { continue }
            activities.append(activity)
        }
        return activities
    }
}

// MARK: - HTTP

private extension PolarV4Client {
    func makeRequest(path: String) -> URLRequest {
        var req = URLRequest(url: URL(string: "\(Self.baseURL)\(path)")!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    func perform(_ request: URLRequest, label: String) async throws -> (Data, Int) {
        let (data, response) = try await urlSession.data(for: request)
        let http = response as! HTTPURLResponse
        #if DEBUG
        let preview = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
        print("📡 \(label): HTTP \(http.statusCode), \(data.count) bytes — \(preview)")
        #endif
        return (data, http.statusCode)
    }

    func fetchSessionList(from: Date, to: Date) async throws -> [V4SessionListItem] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let path = "/training-sessions?from=\(iso.string(from: from))&to=\(iso.string(from: to))"
        let (data, status) = try await perform(makeRequest(path: path),
                                               label: "GET /training-sessions")
        if status == 204 { return [] }
        guard status == 200 else { throw APIError.httpError(statusCode: status) }
        return (try? JSONDecoder().decode([V4SessionListItem].self, from: data)) ?? []
    }

    func fetchSessionDetail(id: String) async throws -> V4Session? {
        let (data, status) = try await perform(makeRequest(path: "/training-sessions/\(id)"),
                                               label: "GET /training-sessions/\(id)")
        guard status == 200 else { return nil }
        return try? JSONDecoder().decode(V4Session.self, from: data)
    }
}

// MARK: - DTOs

private struct V4SessionListItem: Decodable {
    let id: String
}

private struct V4Session: Decodable {
    let id: String
    let startTime: String          // ISO-8601 with offset e.g. "2026-05-30T08:30:00+03:00"
    let duration: String           // ISO-8601 e.g. "PT1H30M"
    let distance: Double?          // metres
    let heartRate: HeartRate?
    let sport: String?
    let hasRoute: Bool?
    let samples: [SampleSeries]?
    let routePoints: [WayPoint]?

    struct HeartRate: Decodable {
        let average: Int?
        let maximum: Int?
    }

    // Same shape as GDPRTrainingSession.SampleSeries.
    // [Double?] handles JSON null natively via JSONDecoder.
    struct SampleSeries: Decodable {
        let type: String
        let intervalMillis: Int
        let values: [Double?]
    }

    struct WayPoint: Decodable {
        let location: Location
        let timeOffsetFromStartMillis: Int

        struct Location: Decodable {
            let longitude: Double
            let latitude: Double
            let altitudeMeters: Double?
        }
    }

    func toActivity() -> Activity? {
        guard let start = Self.parseDate(startTime),
              let dur = PolarV4Client.parseISO8601Duration(duration) else { return nil }

        let dist = distance ?? 0
        let speedSeries = samples?.first(where: { $0.type == "SPEED" })
        let wayPoints = routePoints ?? []

        // Same alignment formula as GDPRTrainingSession.toActivity():
        // idx = timeOffsetFromStartMillis / intervalMillis
        let points: [RoutePoint] = wayPoints.map { wp in
            let t = wp.timeOffsetFromStartMillis
            var speedKmh: Double? = nil
            if let series = speedSeries, series.intervalMillis > 0 {
                let idx = t / series.intervalMillis
                if idx < series.values.count, let v = series.values[idx] {
                    speedKmh = v  // v4 SPEED is in km/h (same as GDPR)
                }
            }
            return RoutePoint(
                latitude: wp.location.latitude,
                longitude: wp.location.longitude,
                altitude: wp.location.altitudeMeters ?? 0,
                elapsedMillis: t,
                speedKmh: speedKmh
            )
        }

        return Activity(
            id: id,
            startTime: start,
            duration: dur,
            distance: dist,
            sportRawValue: sport ?? SportType.other.rawValue,
            avgSpeed: dist > 0 ? dist / dur : 0,
            avgPace:  dist > 0 ? dur / dist : 0,
            avgHeartRate: heartRate?.average,
            maxHeartRate: heartRate?.maximum,
            calories: nil,
            hasRoute: !points.isEmpty,
            routePointsData: points.isEmpty ? nil : try? JSONEncoder().encode(points)
        )
    }

    private static func parseDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
