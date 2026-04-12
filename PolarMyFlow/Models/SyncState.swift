import Foundation
import SwiftData

@Model
final class SyncState {
    var userID: String
    var lastSyncedAt: Date?
    var accessLinkRegistered: Bool
    var historicalImportComplete: Bool

    init(userID: String) {
        self.userID = userID
        self.lastSyncedAt = nil
        self.accessLinkRegistered = false
        self.historicalImportComplete = false
    }
}