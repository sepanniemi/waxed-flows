import SwiftUI

struct PolarBadge: View {
    enum Style { case outline, filled }

    let text: String
    var style: Style = .outline

    var body: some View {
        Text(text)
            .font(.metaDefault)
            .tracking(1.8)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(style == .filled ? Palette.polarNight : Palette.ink)
            .background {
                Capsule().fill(style == .filled ? Palette.polarSky : Color.clear)
            }
            .overlay {
                Capsule().strokeBorder(Palette.surfaceBorder, lineWidth: style == .outline ? 1 : 0)
            }
    }
}
