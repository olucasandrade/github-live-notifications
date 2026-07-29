import SwiftUI

/// Panel open animation (UI-SPEC §1.4): fade + rise 12pt with spring; opacity-only under reduce motion.
struct PanelMotion: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var appeared = false

    private static let rise: CGFloat = 12
    private static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: accessibilityReduceMotion ? 0 : (appeared ? 0 : Self.rise))
            .onAppear {
                if accessibilityReduceMotion {
                    appeared = true
                } else {
                    withAnimation(Self.spring) {
                        appeared = true
                    }
                }
            }
    }
}

extension View {
    func panelMotion() -> some View {
        modifier(PanelMotion())
    }
}
