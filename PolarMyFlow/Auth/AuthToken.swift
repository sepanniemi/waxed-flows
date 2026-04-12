import Foundation

struct AuthToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    var isExpired: Bool { expiresAt <= Date() }

    // expiresIn: seconds until expiry, as returned by Polar token endpoint
    init(accessToken: String, refreshToken: String, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}
