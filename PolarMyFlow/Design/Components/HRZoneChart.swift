import SwiftUI

/// Renders Z1-Z5 bars as fractions (0…1). Fractions above 1 clamp to 1.
///
/// Not currently wired to any screen — the Activity model does not expose
/// zone-time data. Kept here so a future data-model extension can drop it in.
struct HRZoneChart: View {
    /// Five values in Z1…Z5 order, each 0…1 of max height.
    let fractions: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(fractions.prefix(5).enumerated()), id: \.offset) { index, raw in
                    let v = max(0, min(raw, 1))
                    Rectangle()
                        .fill(Self.color(for: index))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(2, 56 * CGFloat(v)))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .frame(height: 56, alignment: .bottom)

            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Text("Z\(index + 1)")
                        .font(.metaSmall)
                        .tracking(1.2)
                        .foregroundStyle(Palette.inkFaint)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private static func color(for index: Int) -> Color {
        switch index {
        case 0, 1: return Palette.polarSky
        case 2:    return Palette.polarSkyLight
        case 3:    return Palette.polarSkyIce
        case 4:    return Palette.polarAmber
        default:   return Palette.polarSky
        }
    }
}
