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

// Maps the actual Polar Dynamic AccessLink v4 training session JSON.
// Schema reference: polar.com/polar-api-v4 — trainingsessionTrainingSession
private struct V4Session: Decodable {
    let id: String
    let startTime: String    // ISO-8601 e.g. "2026-05-30T08:30:00Z"
    let duration: String     // ISO-8601 duration e.g. "PT1H30M"
    let sportId: String?
    let calories: Int?
    let samples: SamplesWrapper?
    let statistics: Statistics?
    let routes: RoutesWrapper?

    // trainingsessionSamples: wrapper object whose "samples" key holds the array
    struct SamplesWrapper: Decodable {
        let samples: [Sample]?

        struct Sample: Decodable {
            let type: String            // "SAMPLE_TYPE_SPEED", "SAMPLE_TYPE_HEART_RATE", …
            let intervalValues: IntervalValues?

            // trainingsessionIntervalValues
            struct IntervalValues: Decodable {
                let interval: String    // recording interval in ms, as a string e.g. "1000"
                let values: [Double?]

                // Custom decoder: Polar encodes missing samples as the string "NaN",
                // not JSON null. A native [Double?] decoder throws on "NaN" strings,
                // silently making the whole samples array nil.
                init(from decoder: Decoder) throws {
                    let c = try decoder.container(keyedBy: CodingKeys.self)
                    interval = try c.decode(String.self, forKey: .interval)
                    var raw = try c.nestedUnkeyedContainer(forKey: .values)
                    var decoded: [Double?] = []
                    while !raw.isAtEnd {
                        if let d = try? raw.decode(Double.self) {
                            decoded.append(d.isFinite && d > 0 ? d : nil)
                        } else if (try? raw.decodeNil()) == true {
                            decoded.append(nil)
                        } else {
                            _ = try? raw.decode(String.self)  // consume "NaN" string
                            decoded.append(nil)
                        }
                    }
                    values = decoded
                }
                enum CodingKeys: String, CodingKey { case interval, values }
            }
        }
    }

    // trainingsessionStatistics: aggregated metrics
    struct Statistics: Decodable {
        let distance: Double?       // km
        let avgHeartRate: Int?
        let maxHeartRate: Int?
    }

    // trainingsessionRoutes: { "route": [ { "routePoints": [...] } ] }
    struct RoutesWrapper: Decodable {
        let route: [Route]?

        struct Route: Decodable {
            let routePoints: [WayPoint]?

            struct WayPoint: Decodable {
                let location: Location?
                let timeOffsetFromStartMillis: Int?

                struct Location: Decodable {
                    let latitude: Double
                    let longitude: Double
                    let altitudeMeters: Double?
                }
            }
        }
    }

    func toActivity() -> Activity? {
        guard let start = Self.parseDate(startTime),
              let dur = PolarV4Client.parseISO8601Duration(duration) else { return nil }

        let distMeters = (statistics?.distance ?? 0) * 1000  // km → metres

        let speedSeries = samples?.samples?.first(where: { $0.type == "SPEED" })
        let wayPoints = routes?.route?.first?.routePoints ?? []

        // idx = timeOffsetFromStartMillis / intervalMs — same alignment as GDPR import
        let points: [RoutePoint] = wayPoints.compactMap { wp in
            guard let loc = wp.location, let t = wp.timeOffsetFromStartMillis else { return nil }
            var speedKmh: Double? = nil
            if let series = speedSeries,
               let iv = series.intervalValues,
               let intervalMs = Int(iv.interval), intervalMs > 0 {
                let idx = t / intervalMs
                if idx < iv.values.count {
                    speedKmh = iv.values[idx]  // v4 SPEED is km/h (same as GDPR)
                }
            }
            return RoutePoint(
                latitude: loc.latitude,
                longitude: loc.longitude,
                altitude: loc.altitudeMeters ?? 0,
                elapsedMillis: t,
                speedKmh: speedKmh
            )
        }

        return Activity(
            id: id,
            startTime: start,
            duration: dur,
            distance: distMeters,
            sportRawValue: sportId ?? SportType.other.rawValue,
            avgSpeed: distMeters > 0 ? distMeters / dur : 0,
            avgPace:  distMeters > 0 ? dur / distMeters : 0,
            avgHeartRate: statistics?.avgHeartRate,
            maxHeartRate: statistics?.maxHeartRate,
            calories: calories,
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
