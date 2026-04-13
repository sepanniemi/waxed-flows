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
    // 409 = already registered — fetch user info and return ID.
    func registerUser() async throws -> String {
        let url = URL(string: "\(Self.baseURL)/v3/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["member-id": "polarmyflow-user"])

        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse

        if http.statusCode == 409 {
            // Already registered — fetch existing user
            return try await fetchCurrentUserID()
        }
        guard http.statusCode == 200 || http.statusCode == 201 else {
            throw APIError.httpError(statusCode: http.statusCode)
        }
        return try parseUserID(from: data)
    }

    // Fetch all new activities via the transaction model.
    // Returns empty array if 204 (no new activities).
    // Commits transaction after successful fetch.
    func pullNewActivities() async throws -> [Activity] {
        // 1. Create transaction
        let transactionURL = URL(string: "\(Self.baseURL)/v3/exercises/transaction")!
        var txRequest = URLRequest(url: transactionURL)
        txRequest.httpMethod = "POST"
        txRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        txRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let (txData, txResponse) = try await session.data(for: txRequest)
        let txHTTP = txResponse as! HTTPURLResponse

        if txHTTP.statusCode == 204 { return [] }
        guard txHTTP.statusCode == 201 else {
            throw APIError.httpError(statusCode: txHTTP.statusCode)
        }

        struct TransactionResponse: Decodable {
            let transactionID: Int
            enum CodingKeys: String, CodingKey { case transactionID = "transaction-id" }
        }
        guard let tx = try? JSONDecoder().decode(TransactionResponse.self, from: txData) else {
            throw APIError.decodingFailed
        }
        let transactionID = tx.transactionID

        // 2. Fetch exercise list
        let listURL = URL(string: "\(Self.baseURL)/v3/exercises/\(transactionID)")!
        var listRequest = URLRequest(url: listURL)
        listRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        listRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let (listData, _) = try await session.data(for: listRequest)

        struct ExerciseRef: Decodable {
            let id: Int
        }
        struct ListResponse: Decodable {
            let exercises: [ExerciseRef]
            enum CodingKeys: String, CodingKey { case exercises }
        }
        guard let list = try? JSONDecoder().decode(ListResponse.self, from: listData) else {
            throw APIError.decodingFailed
        }

        // 3. Fetch detail for each exercise
        var activities: [Activity] = []
        for ref in list.exercises {
            let detailURL = URL(string: "\(Self.baseURL)/v3/exercises/\(transactionID)/\(ref.id)")!
            var detailReq = URLRequest(url: detailURL)
            detailReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            detailReq.setValue("application/json", forHTTPHeaderField: "Accept")
            let (detailData, _) = try await session.data(for: detailReq)
            if let activity = parseExerciseDetail(detailData, transactionID: transactionID) {
                activities.append(activity)
            }
        }

        // 4. Commit transaction
        var commitRequest = URLRequest(url: listURL)
        commitRequest.httpMethod = "PUT"
        commitRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try await session.data(for: commitRequest)

        return activities
    }

    // MARK: - Parsing

    private func fetchCurrentUserID() async throws -> String {
        let url = URL(string: "\(Self.baseURL)/v3/users/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        return try parseUserID(from: data)
    }

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

    private func parseExerciseDetail(_ data: Data, transactionID: Int) -> Activity? {
        struct HeartRate: Decodable {
            let average: Int?
            let maximum: Int?
        }
        struct Detail: Decodable {
            let id: Int
            let startTime: String
            let duration: String
            let calories: Int?
            let distance: Double?
            let heartRate: HeartRate?
            let sport: String?
            let hasRoute: Bool?
            enum CodingKeys: String, CodingKey {
                case id, duration, calories, distance, sport
                case startTime = "start-time"
                case heartRate = "heart-rate"
                case hasRoute = "has-route"
            }
        }
        guard let d = try? JSONDecoder().decode(Detail.self, from: data),
              let dur = Self.parseISO8601Duration(d.duration)
        else { return nil }

        // Try ISO8601 with timezone first, then without
        let startTime: Date
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate]
        if let date = isoFormatter.date(from: d.startTime) {
            startTime = date
        } else {
            // Polar sometimes returns local time without timezone offset
            let localFormatter = DateFormatter()
            localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            localFormatter.locale = Locale(identifier: "en_US_POSIX")
            guard let date = localFormatter.date(from: d.startTime) else { return nil }
            startTime = date
        }

        let dist = d.distance ?? 0.0
        let speed = dist > 0 ? dist / dur : 0.0
        let pace  = dist > 0 ? dur / dist : 0.0

        return Activity(
            id: "\(transactionID)-\(d.id)",
            startTime: startTime,
            duration: dur,
            distance: dist,
            sportRawValue: d.sport ?? SportType.other.rawValue,
            avgSpeed: speed,
            avgPace: pace,
            avgHeartRate: d.heartRate?.average,
            maxHeartRate: d.heartRate?.maximum,
            calories: d.calories,
            hasRoute: d.hasRoute ?? false
        )
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
