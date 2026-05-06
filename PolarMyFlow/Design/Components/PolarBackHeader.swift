import SwiftUI

/// Detail-screen header used by SportDetailView and ActivityDetailView.
/// Shows a tappable "◂ <crumb>" meta-label, a soft rule, and an uppercased
/// title in display type with the standard Polar shadow.
struct PolarBackHeader: View {
    let crumb: String
    let title: String
    var titleFont: Font = .displayMedium
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onDismiss) {
                Text("◂ \(crumb)")
                    .metaLabel()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityHint(crumb)

            PolarRule(variant: .soft)

            Text(title)
                .font(titleFont)
                .textCase(.uppercase)
                .foregroundStyle(Palette.polarSkyLight)
                .displayShadow()
        }
    }
}
