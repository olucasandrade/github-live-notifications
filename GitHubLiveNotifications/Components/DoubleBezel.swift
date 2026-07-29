import SwiftUI

/// Double-bezel chrome from UI-SPEC §1.3: hairline outer ring, 1.5pt pad, soft fill,
/// and an inner material surface.
struct DoubleBezel<Content: View>: View {
    enum InnerMaterial {
        /// Menu panel body.
        case regular
        /// Header signal strip.
        case ultraThin
    }

    var cornerRadius: CGFloat = GHNRadius.panelOuter
    var innerMaterial: InnerMaterial = .regular
    @ViewBuilder var content: () -> Content

    private let bezelPadding: CGFloat = 1.5

    private var innerCornerRadius: CGFloat {
        max(cornerRadius - bezelPadding, 0)
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(materialFill)
            .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous))
            .padding(bezelPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(GHNColor.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(GHNColor.surfaceHairline, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var materialFill: some View {
        switch innerMaterial {
        case .regular:
            Rectangle().fill(.regularMaterial)
        case .ultraThin:
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}
