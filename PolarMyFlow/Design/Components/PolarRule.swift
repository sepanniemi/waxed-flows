import SwiftUI

struct PolarRule: View {
    enum Variant { case soft, full }
    var variant: Variant = .full

    var body: some View {
        switch variant {
        case .soft:
            Rectangle()
                .fill(LinearGradient(
                    colors: [Palette.ink.opacity(0.6), .clear],
                    startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        case .full:
            Rectangle()
                .fill(Palette.ruleSoft)
                .frame(height: 1)
        }
    }
}
