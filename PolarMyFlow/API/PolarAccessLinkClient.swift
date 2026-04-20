import Foundation

final class PolarAccessLinkClient {
    private let session: URLSession
    private let accessToken: String
    private static let baseURL = "https://www.polaraccesslink.com"

    init(session: URLSession = .shared, accessToken: String) {
        self.session = session
        self.accessToken = accessToken
    }

    // Register user with AccessLink. Returns polar-user-id as String.
    // 409 = already registered — not an error, just means we're good.
    func registerUser() async throws -> String {
        var request = makeRequest(path: "/v3/users", method: "POST")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.registerBody.data(using: .utf8)

        let (data, status) = try await perform(request, label: "register user")
        if status == 409 { return "registered" }
        guard status == 200 || status == 201 else {
            throw APIError.httpError(statusCode: status)
        }

        struct UserResponse: Decodable {
            let polarUserID: Int
            enum CodingKeys: String, CodingKey { case polarUserID = "polar-user-id" }
        }
        guard let r = try? JSONDecoder().decode(UserResponse.self, from: data) else {
            throw APIError.decodingFailed
        }
        return "\(r.polarUserID)"
    }

    // Fetch exercises from AccessLink (last 30 days of data uploaded to Flow).
    func pullNewActivities() async throws -> [Activity] {
        let request = makeRequest(path: "/v3/exercises", method: "GET")
        let (data, status) = try await perform(request, label: "GET /v3/exercises")
        if status == 204 { return [] }
        guard status == 200 else { throw APIError.httpError(statusCode: status) }

        guard let exercises = try? JSONDecoder().decode([AccessLinkExercise].self, from: data) else {
            throw APIError.decodingFailed
        }
        return exercises.compactMap { $0.toActivity() }
    }

    // MARK: - Private

    private func makeRequest(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "\(Self.baseURL)\(path)")!)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform(_ request: URLRequest, label: String) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse
        #if DEBUG
        let preview = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
        print("📡 \(label): HTTP \(http.statusCode), \(data.count) bytes — \(preview)")
        #endif
        return (data, http.statusCode)
    }

    private static let registerBody = """
    <?xml version="1.0" encoding="UTF-8" ?>
    <register>
      <member-id>polarmyflow-user</member-id>
    </register>
    """

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

// MARK: - DTO

// Mirrors AccessLink's /v3/exercises shape. Kept as its own file-private
// type so the client stays focused on HTTP and the mapping lives with the
// data — same pattern as GDPRTrainingSession.
private struct AccessLinkExercise: Decodable {
    let id: String
    let start_time: String           // "2008-10-13T10:40:02" (naive local)
    let duration: String             // ISO-8601 duration e.g. "PT2H44M"
    let calories: Int?
    let distance: Double?
    let heart_rate: HeartRate?
    let sport: String?
    let has_route: Bool?
    let detailed_sport_info: String?

    struct HeartRate: Decodable {
        let average: Int?
        let maximum: Int?
    }

    func toActivity() -> Activity? {
        guard let dur = PolarAccessLinkClient.parseISO8601Duration(duration),
              let start = Self.parseDate(start_time) else { return nil }

        let dist = distance ?? 0
        let sportStr = detailed_sport_info ?? sport ?? SportType.other.rawValue

        return Activity(
            id: id,
            startTime: start,
            duration: dur,
            distance: dist,
            sportRawValue: sportStr,
            avgSpeed: dist > 0 ? dist / dur : 0,
            avgPace:  dist > 0 ? dur / dist : 0,
            avgHeartRate: heart_rate?.average,
            maxHeartRate: heart_rate?.maximum,
            calories: calories,
            hasRoute: has_route ?? false
        )
    }

    // AccessLink returns naive local strings ("2008-10-13T10:40:02"), but
    // occasionally an ISO-8601 offset. Parse the naive form as device-local
    // (same policy as GDPR import), fall back to ISO-8601.
    private static let naiveFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func parseDate(_ s: String) -> Date? {
        naiveFormatter.date(from: s) ?? isoFormatter.date(from: s)
    }
}

protocol AccessLinkClientProtocol {
    func registerUser() async throws -> String
    func pullNewActivities() async throws -> [Activity]
}

extension PolarAccessLinkClient: AccessLinkClientProtocol {}
