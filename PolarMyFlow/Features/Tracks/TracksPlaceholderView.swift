import SwiftUI

struct TracksPlaceholderView: View {
    var body: some View {
        ZStack {
            Image("tracksMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 220)
                .foregroundStyle(Palette.ink.opacity(0.08))
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Tracks")
                    .font(.displayMedium)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.ink)
                    .displayShadow()
                Text("Coming · 2026 · Summer")
                    .metaLabel()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .polarBackground()
    }
}
