import Foundation

final class PolarAccessLinkClient {
    private let session: URLSession
    private var accessToken: String
    private static let baseURL = "https://www.polaraccesslink.com"

    init(session: URLSession = .shared, accessToken: String) {
        self.session = session
        self.accessToken = accessToken
    }

    // Register user with AccessLink. Returns polar-user-id as String.
    // 409 = already registered — not an error, just means we're good.
    func registerUser() async throws -> String {
        let url = URL(string: "\(Self.baseURL)/v3/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <register>
          <member-id>polarmyflow-user</member-id>
        </register>
        """
        request.httpBody = xml.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse

        #if DEBUG
        print("📡 Register user: HTTP \(http.statusCode)")
        if let body = String(data: data, encoding: .utf8) { print("📡 Response: \(body)") }
        #endif

        if http.statusCode == 409 {
            // Already registered — that's fine
            return "registered"
        }
        guard http.statusCode == 200 || http.statusCode == 201 else {
            throw APIError.httpError(statusCode: http.statusCode)
        }
        return try parseUserID(from: data)
    }

    // Fetch exercises from AccessLink (last 30 days of data uploaded to Flow).
    // Simple GET — no transaction model needed.
    func pullNewActivities() async throws -> [Activity] {
        let url = URL(string: "\(Self.baseURL)/v3/exercises")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse

        #if DEBUG
        print("📡 GET /v3/exercises: HTTP \(http.statusCode)")
        if let body = String(data: data, encoding: .utf8) {
            print("📡 Response (\(data.count) bytes): \(body.prefix(500))")
        }
        #endif

        if http.statusCode == 204 { return [] }
        guard http.statusCode == 200 else {
            throw APIError.httpError(statusCode: http.statusCode)
        }

        return try parseExercises(from: data)
    }

    // MARK: - Parsing

    private func parseUserID(from data: Data) throws -> String {
        struct UserResponse: Decodable {
            let polarUserID: Int
            enum CodingKeys: String, CodingKey { case polarUserID = "polar-user-id" }
        }
        guard let r = try? JSONDecoder().decode(UserResponse.self, from: data) else {
            throw APIError.decodingFailed
        }
        return "\(r.polarUserID)"
    }

    private func parseExercises(from data: Data) throws -> [Activity] {
        struct HeartRate: Decodable {
            let average: Int?
            let maximum: Int?
        }
        struct Exercise: Decodable {
            let id: String
            let start_time: String           // "2008-10-13T10:40:02"
            let duration: String             // "PT2H44M"
            let calories: Int?
            let distance: Double?
            let heart_rate: HeartRate?
            let sport: String?
            let has_route: Bool?
            let detailed_sport_info: String?
        }

        guard let exercises = try? JSONDecoder().decode([Exercise].self, from: data) else {
            #if DEBUG
            print("📡 Failed to decode exercises JSON")
            #endif
            throw APIError.decodingFailed
        }

        #if DEBUG
        print("📡 Parsed \(exercises.count) exercises")
        #endif

        return exercises.compactMap { e in
            guard let dur = Self.parseISO8601Duration(e.duration) else {
                #if DEBUG
                print("📡 Skipping exercise \(e.id): bad duration '\(e.duration)'")
                #endif
                return nil
            }

            let startTime: Date
            let localFormatter = DateFormatter()
            localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            localFormatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = localFormatter.date(from: e.start_time) {
                startTime = date
            } else {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime]
                guard let date = isoFormatter.date(from: e.start_time) else {
                    #if DEBUG
                    print("📡 Skipping exercise \(e.id): bad start_time '\(e.start_time)'")
                    #endif
                    return nil
                }
                startTime = date
            }

            let dist = e.distance ?? 0.0
            let speed = dist > 0 ? dist / dur : 0.0
            let pace  = dist > 0 ? dur / dist : 0.0

            // Use detailed_sport_info if available, fall back to sport
            let sportStr = e.detailed_sport_info ?? e.sport ?? SportType.other.rawValue

            return Activity(
                id: e.id,
                startTime: startTime,
                duration: dur,
                distance: dist,
                sportRawValue: sportStr,
                avgSpeed: speed,
                avgPace: pace,
                avgHeartRate: e.heart_rate?.average,
                maxHeartRate: e.heart_rate?.maximum,
                calories: e.calories,
                hasRoute: e.has_route ?? false
            )
        }
    }

    // Internal for testing
    static func parseISO8601Duration(_ string: String) -> TimeInterval? {
        guard string.hasPrefix("PT") else { return nil }
        var remaining = String(string.dropFirst(2))
        var total: Double = 0
        for (unit, multiplier) in [("H", 3600.0), ("M", 60.0), ("S", 1.0)] {
            if let range = remaining.range(of: unit) {
                let valueStr = String(remaining[remaining.startIndex..<range.lowerBound])
                if let value = Double(valueStr) { total += value * multiplier }
                remaining = String(remaining[range.upperBound...])
            }
        }
        return total > 0 ? total : nil
    }
}

protocol AccessLinkClientProtocol {
    func registerUser() async throws -> String
    func pullNewActivities() async throws -> [Activity]
}

extension PolarAccessLinkClient: AccessLinkClientProtocol {}
