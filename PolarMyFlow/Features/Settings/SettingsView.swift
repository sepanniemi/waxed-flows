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
    @AppStorage("com.personal.polarmyflow.importYearsBack") private var storedYearsBack: Int = 4

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    importHistorySection
                    #if DEBUG
                    debugSection
                    #endif
                    accountSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 48)
                .padding(.bottom, 40)
            }
            .polarBackground()
            .navigationBarHidden(true)
            .alert("Export requested", isPresented: $showExportInstructions) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("Polar will email you a download link within a few hours to a few days. When it arrives, tap the link and choose Waxed Flows to share the ZIP into the app. By default Waxed Flows only imports the last 4 years — change Import window above if you want more or fewer years.")
            }
            .onReceive(NotificationCenter.default.publisher(for: .importZipReceived)) { note in
                guard let url = note.object as? URL else { return }
                Task { await runImport(url: url) }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings").metaLabel()
            PolarRule(variant: .soft)
        }
    }

    private var importHistorySection: some View {
        settingsGroup(title: "Import History") {
            actionRow(systemIcon: "arrow.down.doc", title: "Request data export from Polar") {
                openPolarExportPage()
            }

            pickerRow(title: "Import Window", selection: $storedYearsBack, options: [
                (2, "Last 2 years"),
                (4, "Last 4 years"),
                (-1, "All time"),
            ])
            .disabled(importer?.isRunning == true)

            actionRow(systemIcon: "square.and.arrow.down", title: "Import from file…") {
                showFileImporter = true
            }
            .disabled(importer?.isRunning == true)

            if let importer, importer.isRunning || importer.processed > 0 {
                ImportProgressView(importer: importer)
            }
            if let completionMessage {
                Text(completionMessage)
                    .font(.bodyCaption)
                    .foregroundStyle(Palette.inkMuted)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.bodyCaption)
                    .foregroundStyle(Palette.polarAmber)
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        settingsGroup(title: "Debug") {
            NavigationLink {
                DebugSettingsView()
                    .polarBackground()
            } label: {
                rowShell {
                    Text("Debug settings")
                        .font(.bodyDefault)
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Text("›")
                        .font(.bodyDefault)
                        .foregroundStyle(Palette.inkFaint)
                }
            }
            .buttonStyle(.plain)
        }
    }
    #endif

    private var accountSection: some View {
        settingsGroup(title: "Account") {
            Button {
                do { try authManager.signOut() }
                catch { print("⚠️ Sign-out failed: \(error)") }
            } label: {
                rowShell {
                    Text("Sign out")
                        .font(.bodyDefault)
                        .foregroundStyle(Palette.polarAmber)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).metaLabel()
            PolarCard {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
            }
        }
    }

    private func actionRow(systemIcon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowShell {
                PolarActionIcon(systemName: systemIcon)
                Text(title)
                    .font(.bodyDefault)
                    .foregroundStyle(Palette.ink)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func pickerRow<Value: Hashable>(
        title: String,
        selection: Binding<Value>,
        options: [(Value, String)]
    ) -> some View {
        HStack {
            Text(title)
                .font(.bodyDefault)
                .foregroundStyle(Palette.ink)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options, id: \.0) { opt in
                    Text(opt.1).tag(opt.0)
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.polarSkyLight)
        }
    }

    @ViewBuilder
    private func rowShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            content()
        }
        .contentShape(Rectangle())
    }

    private func openPolarExportPage() {
        let url = URL(string: "https://account.polar.com/")!
        Task { @MainActor in
            UIApplication.shared.open(url) { success in
                if success {
                    showExportInstructions = true
                } else {
                    errorMessage = "Couldn't open account.polar.com — open it manually in your browser to request the export."
                }
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
            let years: Int? = storedYearsBack >= 0 ? storedYearsBack : nil
            try await imp.importHistory(from: url, yearsBack: years)
            completionMessage = "Imported \(imp.imported) activities. "
                + "\(imp.skipped) duplicates skipped, \(imp.failed) files couldn't be read."
        } catch ImportError.cancelled {
            completionMessage = "Import cancelled. Kept \(imp.imported) activities."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
