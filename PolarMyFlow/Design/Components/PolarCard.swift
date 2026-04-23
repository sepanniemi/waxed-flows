import SwiftUI

struct PolarCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Palette.surfaceGlass, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Palette.surfaceBorder, lineWidth: 1)
            )
    }
}
