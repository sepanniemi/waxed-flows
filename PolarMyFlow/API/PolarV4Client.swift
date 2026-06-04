import Foundation

final class PolarV4Client {
    private let urlSession: URLSession
    private let accessToken: String
    private static let baseURL = "https://www.polaraccesslink.com/v4/data"

    init(session: URLSession = .shared, accessToken: String) {
        self.urlSession = session
        self.accessToken = accessToken
    }
}

// MARK: - AccessLinkClientProtocol

extension PolarV4Client: AccessLinkClientProtocol {
    func registerUser() async throws -> String {
        return "polar-v4"
    }

    func pullNewActivities(since: Date?) async throws -> [Activity] {
        let to = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: to)!
        let sevenDaysAgo  = Calendar.current.date(byAdding: .day, value:  -7, to: to)!
        // Always look back at least 7 days so a prematurely-advanced lastSyncedAt
        // doesn't create a gap. On first sync use 30 days.
        let from = since.map { min($0, sevenDaysAgo) } ?? thirtyDaysAgo
        let sessions = try await fetchSessions(from: from, to: to)
        return sessions.compactMap { $0.toActivity() }
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

    // API requires datetime (not date-only) and limits to one day per request when features are used.
    // We loop day by day to fetch samples+routes for each day in range.
    func fetchSessions(from: Date, to: Date) async throws -> [V4Session] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        df.timeZone = TimeZone(secondsFromGMT: 0)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var dayStart = cal.startOfDay(for: from)

        var all: [V4Session] = []
        while dayStart < to {
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
            var components = URLComponents(string: "\(Self.baseURL)/training-sessions/list")!
            components.queryItems = [
                URLQueryItem(name: "from",     value: df.string(from: dayStart)),
                URLQueryItem(name: "to",       value: df.string(from: dayEnd)),
                URLQueryItem(name: "features", value: "samples"),
                URLQueryItem(name: "features", value: "routes"),
            ]
            var req = URLRequest(url: components.url!)
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json",       forHTTPHeaderField: "Accept")
            let (data, status) = try await perform(req, label: "GET /training-sessions \(df.string(from: dayStart))")
            if status != 204 {
                guard status == 200 else { throw APIError.httpError(statusCode: status) }
                struct ListResponse: Decodable { let trainingSessions: [V4Session] }
                if let sessions = (try? JSONDecoder().decode(ListResponse.self, from: data))?.trainingSessions {
                    all.append(contentsOf: sessions)
                }
            }
            dayStart = dayEnd
        }
        return all
    }
}

// MARK: - DTOs

// Schema verified against actual Polar Dynamic AccessLink v4 API response.
private struct V4Session: Decodable {
    struct Identifier: Decodable { let id: String }
    struct Sport: Decodable { let id: String }

    let identifier: Identifier
    let startTime: String       // ISO-8601 e.g. "2026-06-02T14:01:13.565Z"
    let durationMillis: Int     // session duration in milliseconds
    let distanceMeters: Double?
    let calories: Int?
    let hrAvg: Int?
    let hrMax: Int?
    let sport: Sport?
    let exercises: [Exercise]?

    // All per-point sensor data lives inside exercises[0]
    struct Exercise: Decodable {
        let distanceMeters: Double?
        let ascentMeters: Double?
        let descentMeters: Double?
        let samples: SamplesWrapper?
        let routes: RoutesWrapper?

        struct SamplesWrapper: Decodable {
            let samples: [SampleSeries]?

            // Same shape as GDPRTrainingSession.SampleSeries.
            // Custom decoder: Polar encodes missing values as the string "NaN"
            // (not JSON null). Native [Double?] throws on "NaN" strings, making
            // the whole samples array nil and losing all speed data.
            struct SampleSeries: Decodable {
                let type: String          // e.g. "SPEED", "HEART_RATE"
                let intervalMillis: Int   // recording interval in ms
                let values: [Double?]

                init(from decoder: Decoder) throws {
                    let c = try decoder.container(keyedBy: CodingKeys.self)
                    type = try c.decode(String.self, forKey: .type)
                    intervalMillis = try c.decode(Int.self, forKey: .intervalMillis)
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
                enum CodingKeys: String, CodingKey { case type, intervalMillis, values }
            }
        }

        // routes.route is a single object (not an array)
        // wayPoints use elapsedMillis (same field name as GDPR waypoints)
        struct RoutesWrapper: Decodable {
            let route: Route?

            struct Route: Decodable {
                let wayPoints: [WayPoint]?

                struct WayPoint: Decodable {
                    let longitude: Double
                    let latitude: Double
                    let altitude: Double?
                    let elapsedMillis: Int?
                }
            }
        }
    }

    func toActivity() -> Activity? {
        guard let start = Self.parseDate(startTime), durationMillis > 0 else { return nil }
        let dur = Double(durationMillis) / 1000.0
        let exercise = exercises?.first

        let dist = distanceMeters ?? exercise?.distanceMeters ?? 0
        let sportId = sport.flatMap { Int($0.id) } ?? -1
        let sportStr = SportType.from(polarSportId: sportId).rawValue

        let speedSeries = exercise?.samples?.samples?.first(where: { $0.type == "SPEED" })
        let wayPoints = exercise?.routes?.route?.wayPoints ?? []

        // Same alignment formula as GDPRTrainingSession.toActivity():
        // idx = elapsedMillis / intervalMillis
        let points: [RoutePoint] = wayPoints.compactMap { wp in
            guard let t = wp.elapsedMillis else { return nil }
            var speedKmh: Double? = nil
            if let series = speedSeries, series.intervalMillis > 0 {
                let idx = t / series.intervalMillis
                if idx < series.values.count {
                    speedKmh = series.values[idx]  // SPEED series is in km/h
                }
            }
            return RoutePoint(
                latitude: wp.latitude,
                longitude: wp.longitude,
                altitude: wp.altitude ?? 0,
                elapsedMillis: t,
                speedKmh: speedKmh
            )
        }

        return Activity(
            id: identifier.id,
            startTime: start,
            duration: dur,
            distance: dist,
            sportRawValue: sportStr,
            avgSpeed: dist > 0 ? dist / dur : 0,
            avgPace:  dist > 0 ? dur / dist : 0,
            avgHeartRate: hrAvg,
            maxHeartRate: hrMax,
            ascent: exercise?.ascentMeters,
            descent: exercise?.descentMeters,
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
        if let d = f.date(from: s) { return d }
        // Polar API omits timezone on startTime — treat as UTC
        let df = DateFormatter()
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let d = df.date(from: s) { return d }
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df.date(from: s)
    }
}
