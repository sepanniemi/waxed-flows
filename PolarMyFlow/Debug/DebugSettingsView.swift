#if DEBUG
import SwiftUI
import SwiftData

extension Notification.Name {
    static let debugResetSync = Notification.Name("debug.resetSync")
}

struct DebugSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Reset Sync & Re-import", role: .destructive) {
                        resetSync()
                    }
                } footer: {
                    Text("Clears sync state so the app re-imports from AccessLink on next launch.")
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func resetSync() {
        let descriptor = FetchDescriptor<SyncState>()
        if let states = try? modelContext.fetch(descriptor) {
            for state in states {
                state.historicalImportComplete = false
                state.accessLinkRegistered = false
                state.lastSyncedAt = nil
            }
            try? modelContext.save()
        }
        dismiss()
        NotificationCenter.default.post(name: .debugResetSync, object: nil)
    }
}
#endif
