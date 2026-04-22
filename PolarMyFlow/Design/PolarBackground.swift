import SwiftUI

struct PolarBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    LinearGradient(
                        colors: [Palette.polarNight, Palette.polarDeep, Palette.polarRoyal],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    RadialGradient(
                        colors: [Palette.polarSky.opacity(0.35), .clear],
                        center: UnitPoint(x: 1.0, y: 0.0),
                        startRadius: 0,
                        endRadius: 420
                    )
                    .blendMode(.screen)
                    .ignoresSafeArea()
                }
            }
            .foregroundStyle(Palette.ink)
            .preferredColorScheme(.dark)
    }
}

extension View {
    func polarBackground() -> some View { modifier(PolarBackground()) }
}
