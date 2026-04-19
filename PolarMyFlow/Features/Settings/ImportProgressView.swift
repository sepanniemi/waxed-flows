import SwiftUI

struct ImportProgressView: View {
    @Bindable var importer: HistoryImporter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProgressView(value: Double(importer.processed),
                             total: Double(max(importer.total, 1)))
                Text("\(importer.processed) / \(importer.total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Label("\(importer.imported)", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                if importer.skipped > 0 {
                    Label("\(importer.skipped) duplicates",
                          systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                }
                if importer.failed > 0 {
                    Label("\(importer.failed) errors",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)

            Button("Cancel") { importer.cancel() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding()
        .background(.bar, in: .rect(cornerRadius: 10))
    }
}
