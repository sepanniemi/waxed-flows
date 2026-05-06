import SwiftUI

/// One of the five allow-listed chrome SF Symbols with a standard tint.
/// Allowed: checkmark.circle, arrow.triangle.2.circlepath, exclamationmark.triangle,
/// square.and.arrow.down, arrow.down.doc.
struct PolarActionIcon: View {
    let systemName: String
    var size: CGFloat = 14
    var tint: Color = Palette.polarSkyLight

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }
}
