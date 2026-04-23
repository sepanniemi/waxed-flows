import SwiftUI

enum PolarTab: Int, CaseIterable, Identifiable {
    case dash, log, tracks, settings
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .dash:     return "Dash"
        case .log:      return "Log"
        case .tracks:   return "Tracks"
        case .settings: return "Set"
        }
    }

    var glyph: String {
        switch self {
        case .dash:     return "◆"
        case .log:      return "≡"
        case .tracks:   return "△"
        case .settings: return "⚙"
        }
    }
}

struct PolarTabBar: View {
    @Binding var selection: PolarTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PolarTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    tabContent(tab)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(tab == selection ? .isSelected : [])
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            Palette.polarNight.opacity(0.88)
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.surfaceBorder)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: PolarTab) -> some View {
        let isActive = tab == selection
        VStack(spacing: 6) {
            Text(tab.glyph)
                .font(.system(size: 20))
            Text(tab.label)
                .font(.displayTab)
                .tracking(0.5)
                .textCase(.uppercase)
        }
        .foregroundStyle(isActive ? Palette.polarSkyLight : Palette.ink.opacity(0.55))
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle()
                    .fill(Palette.polarSkyLight)
                    .frame(height: 2)
                    .padding(.horizontal, 24)
                    .offset(y: 8)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
