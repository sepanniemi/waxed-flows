import SwiftUI
import SwiftData
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @State private var importer: HistoryImporter?
    @State private var showExportInstructions = false
    @State private var showFileImporter = false
    @State private var errorMessage: String?
    @State private var completionMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Import history") {
                    Button {
                        openPolarExportPage()
                    } label: {
                        Label("Request data export from Polar",
                              systemImage: "arrow.down.doc")
                    }
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Import from file…",
                              systemImage: "square.and.arrow.down")
                    }
                    .disabled(importer?.isRunning == true)

                    if let importer, importer.isRunning || importer.processed > 0 {
                        ImportProgressView(importer: importer)
                    }
                    if let completionMessage {
                        Text(completionMessage).foregroundStyle(.secondary)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                #if DEBUG
                Section("Debug") {
                    NavigationLink("Debug settings") { DebugSettingsView() }
                }
                #endif

                Section {
                    Button("Sign out", role: .destructive) {
                        try? authManager.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Export requested", isPresented: $showExportInstructions) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("Polar will email you a download link within a few hours to a few days. When it arrives, tap the link and choose PolarMyFlow to share the ZIP into the app.")
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.zip]
            ) { result in
                switch result {
                case .success(let url): Task { await runImport(url: url) }
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func openPolarExportPage() {
        let url = URL(string: "https://account.polar.com/")!
        Task { @MainActor in
            UIApplication.shared.open(url) { _ in
                showExportInstructions = true
            }
        }
    }

    @MainActor
    func runImport(url: URL) async {
        errorMessage = nil
        completionMessage = nil
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let imp = HistoryImporter(context: ModelContext(modelContext.container))
        importer = imp
        do {
            try await imp.importHistory(from: url)
            completionMessage = "Imported \(imp.imported) activities. "
                + "\(imp.skipped) duplicates skipped, \(imp.failed) files couldn't be read."
        } catch ImportError.cancelled {
            completionMessage = "Import cancelled. Kept \(imp.imported) activities."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
