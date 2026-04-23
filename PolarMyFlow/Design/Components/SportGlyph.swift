import SwiftUI

struct SportGlyph: View {
    let sport: SportType
    var size: CGFloat = 24
    var tint: Color = Palette.polarSkyLight

    var body: some View {
        Image(sport.iconName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
    }
}
