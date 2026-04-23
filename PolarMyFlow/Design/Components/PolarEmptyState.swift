import SwiftUI

struct PolarEmptyState: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("tracksMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(Palette.ink.opacity(0.4))

            Text(title)
                .font(.displayMedium)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Palette.ink)
                .displayShadow()

            Text(description)
                .font(.bodyDefault)
                .foregroundStyle(Palette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
