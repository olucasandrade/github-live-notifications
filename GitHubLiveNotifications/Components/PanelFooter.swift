import AppKit
import SwiftUI

/// Panel footer actions (UI-SPEC §2.3).
struct PanelFooter: View {
    var onMarkAllRead: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(GHNColor.surfaceHairline)

            HStack(spacing: 12) {
                Button("Open GitHub") {
                    NSWorkspace.shared.open(Self.notificationsURL)
                }
                .buttonStyle(PanelPrimaryButtonStyle())

                if let onMarkAllRead {
                    Button("Mark all read") {
                        onMarkAllRead()
                    }
                    .font(GHNFont.meta)
                    .foregroundStyle(GHNColor.textSecondary)
                    .buttonStyle(.borderless)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Button("Settings…") {
                        openSettingsWindow()
                    }
                    .font(GHNFont.meta)
                    .foregroundStyle(GHNColor.textTertiary)
                    .buttonStyle(.borderless)

                    Text("·")
                        .font(GHNFont.meta)
                        .foregroundStyle(GHNColor.textTertiary)

                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .font(GHNFont.meta)
                    .foregroundStyle(GHNColor.textTertiary)
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private static let notificationsURL = URL(string: "https://github.com/notifications")!

    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

private struct PanelPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GHNFont.panelTitle)
            .foregroundStyle(GHNColor.accentSignal)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
