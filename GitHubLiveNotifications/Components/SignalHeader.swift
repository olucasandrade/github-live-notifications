import SwiftUI

/// Signal strip header (UI-SPEC §2.1): pip, status copy, refresh control.
struct SignalHeader: View {
    var status: PanelStatus
    var isPolling: Bool
    var refreshBlocked: Bool
    var onRefresh: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var pipOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(GHNColor.accentSignal)
                .frame(width: 8, height: 8)
                .opacity(pipOpacity)
                .accessibilityHidden(true)

            Text(status.statusCopy())
                .font(GHNFont.mono)
                .foregroundStyle(statusTextColor)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(refreshBlocked ? GHNColor.textTertiary : GHNColor.textSecondary)
            }
            .buttonStyle(PanelIconButtonStyle())
            .disabled(refreshBlocked)
            .help(refreshBlocked ? "Notifications refresh blocked by poll interval" : "Refresh now")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear { updatePipAnimation() }
        .onChange(of: isPolling) { _ in updatePipAnimation() }
        .onChange(of: accessibilityReduceMotion) { _ in updatePipAnimation() }
    }

    private var statusTextColor: Color {
        if status.usesDangerColor { return GHNColor.stateDanger }
        if status.usesWarnColor { return GHNColor.stateWarn }
        return GHNColor.textSecondary
    }

    private func updatePipAnimation() {
        guard isPolling, !accessibilityReduceMotion else {
            pipOpacity = 1.0
            return
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pipOpacity = 0.4
        }
    }
}

/// Subtle press feedback for icon buttons (UI-SPEC §1.4).
private struct PanelIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
