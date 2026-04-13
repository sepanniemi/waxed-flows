import Foundation
import AuthenticationServices
import UIKit

enum AuthError: Error {
    case noCallbackURL
    case noAuthCode
    case tokenExchangeFailed(Error)
    case notAuthenticated
}

@MainActor
@Observable
final class AuthManager: NSObject {
    private(set) var isAuthenticated: Bool = false
    private(set) var currentUserID: String?
    private(set) var currentToken: AuthToken?

    private let tokenStore: TokenStore
    private let session: URLSession

    // Polar API constants
    static let clientID     = "c045142a-470a-4d0c-8f44-b8aa1200e975"
    static let clientSecret = "59ccbd6e-aaae-4881-b121-a3b7774ff03b"
    static let redirectURI  = "polarflow://auth"
    static let authURLBase  = "https://flow.polar.com/oauth2/authorization"
    static let tokenURL     = "https://polarremote.com/v2/oauth2/token"

    private let userIDKey = "polarflow.userID"

    init(tokenStore: TokenStore = KeychainStore(), session: URLSession = .shared) {
        self.tokenStore = tokenStore
        self.session = session
    }

    // Call on app launch to restore session from Keychain + UserDefaults
    func restoreSession() {
        guard let token = try? tokenStore.load() else { return }
        currentToken = token
        isAuthenticated = true
        currentUserID = UserDefaults.standard.string(forKey: userIDKey)
    }

    // Opens Polar OAuth in ASWebAuthenticationSession
    func authenticate() async throws {
        var components = URLComponents(string: Self.authURLBase)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id",     value: Self.clientID),
            URLQueryItem(name: "redirect_uri",  value: Self.redirectURI),
            URLQueryItem(name: "scope",         value: "accesslink.read_all")
        ]
        let authURL = components.url!

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let webSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "polarflow"
            ) { url, error in
                if let error { continuation.resume(throwing: error); return }
                guard let url else { continuation.resume(throwing: AuthError.noCallbackURL); return }
                continuation.resume(returning: url)
            }
            webSession.presentationContextProvider = self
            webSession.prefersEphemeralWebBrowserSession = false
            webSession.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw AuthError.noAuthCode }

        let token = try await exchangeCode(code)
        try tokenStore.save(token)
        currentToken = token
        isAuthenticated = true
    }

    // Refresh expired token using refresh token
    func refreshIfNeeded() async throws {
        guard let token = currentToken, token.isExpired else { return }
        let refreshed = try await refreshToken(token.refreshToken)
        try tokenStore.save(refreshed)
        currentToken = refreshed
    }

    func signOut() throws {
        try tokenStore.delete()
        currentToken = nil
        isAuthenticated = false
        currentUserID = nil
        UserDefaults.standard.removeObject(forKey: userIDKey)
    }

    func setUserID(_ id: String) {
        currentUserID = id
        UserDefaults.standard.set(id, forKey: userIDKey)
    }

    // MARK: - Private

    private func exchangeCode(_ code: String) async throws -> AuthToken {
        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let credentials = Data("\(Self.clientID):\(Self.clientSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI)
        ]
        request.httpBody = bodyComponents.query?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "(empty)"
            throw AuthError.tokenExchangeFailed(NSError(domain: "PolarAuth",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"]))
        }
        return try decodeTokenResponse(data)
    }

    private func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let credentials = Data("\(Self.clientID):\(Self.clientSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.httpBody = "grant_type=refresh_token&refresh_token=\(refreshToken)"
            .data(using: .utf8)

        let (data, _) = try await session.data(for: request)
        return try decodeTokenResponse(data)
    }

    private func decodeTokenResponse(_ data: Data) throws -> AuthToken {
        struct Response: Decodable {
            let access_token: String
            let refresh_token: String?  // Polar may omit this on first exchange
            let expires_in: Int?
        }
        do {
            let r = try JSONDecoder().decode(Response.self, from: data)
            return AuthToken(
                accessToken: r.access_token,
                refreshToken: r.refresh_token ?? "",
                expiresIn: r.expires_in ?? 21600
            )
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "(binary)"
            throw AuthError.tokenExchangeFailed(NSError(
                domain: "PolarAuth", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Decode failed. Response: \(raw)"]
            ))
        }
    }
}

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
