import SwiftUI

struct ImportProgressView: View {
    @Bindable var importer: HistoryImporter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(progressFraction * 100))%")
                    .font(.displaySmall)
                    .foregroundStyle(Palette.ink)
                    .displayShadow()
                Spacer()
                Text("\(importer.processed) / \(importer.total) Files")
                    .metaLabel()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surfaceBorder)
                    Capsule()
                        .fill(Palette.polarSky)
                        .frame(width: proxy.size.width * progressFraction)
                }
            }
            .frame(height: 2)

            HStack(spacing: 14) {
                statusChip(
                    systemName: "checkmark.circle",
                    text: "\(importer.imported)",
                    tint: Palette.polarSky
                )
                if importer.skipped > 0 {
                    statusChip(
                        systemName: "arrow.triangle.2.circlepath",
                        text: "\(importer.skipped) dup",
                        tint: Palette.polarSkyIce
                    )
                }
                if importer.failed > 0 {
                    statusChip(
                        systemName: "exclamationmark.triangle",
                        text: "\(importer.failed) err",
                        tint: Palette.polarAmber
                    )
                }
                Spacer()
                Button("Cancel") { importer.cancel() }
                    .font(.metaDefault)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.polarSkyLight)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Palette.surfaceGlass, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Palette.surfaceBorder, lineWidth: 1)
        )
    }

    private var progressFraction: Double {
        guard importer.total > 0 else { return 0 }
        return min(1, Double(importer.processed) / Double(importer.total))
    }

    private func statusChip(systemName: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            PolarActionIcon(systemName: systemName, size: 12, tint: tint)
            Text(text)
                .font(.metaDefault)
                .tracking(1.2)
                .foregroundStyle(tint)
        }
    }
}
