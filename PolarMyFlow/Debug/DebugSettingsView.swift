#if DEBUG
import SwiftUI
import SwiftData

extension Notification.Name {
    static let debugResetSync = Notification.Name("debug.resetSync")
}

enum DebugConfig {
    private static let key = "debug.lookbackDays"
    static var lookbackDays: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: key)
            return stored > 0 ? stored : 30
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct DebugSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var lookbackDays = DebugConfig.lookbackDays

    private let options = [7, 14, 30, 60, 90]

    var body: some View {
        NavigationStack {
            Form {
                Section("History Window") {
                    Picker("Lookback", selection: $lookbackDays) {
                        ForEach(options, id: \.self) { Text("\($0) days").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("Fetches activities from the last \(lookbackDays) days on next import.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Reset Sync & Re-import", role: .destructive) {
                        resetSync()
                    }
                } footer: {
                    Text("Clears sync state so the app re-imports using the selected window. Flow web API is not transaction-based — safe to repeat.")
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: lookbackDays) { _, new in
                DebugConfig.lookbackDays = new
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
