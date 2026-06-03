import Foundation

protocol AccessLinkClientProtocol {
    func registerUser() async throws -> String
    /// Fetch new activities. `since` is the timestamp of the last successful sync;
    /// `nil` means first sync, use a sensible default lookback window.
    func pullNewActivities(since: Date?) async throws -> [Activity]
}
