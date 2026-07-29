import SwiftUI

/// MenuBarExtra `.window` panel shell (UI-SPEC §2). Section lists land in T4.3.
struct MenuPanelView: View {
    var status: PanelStatus
    var isPolling: Bool
    var refreshBlocked: Bool
    var onRefresh: () -> Void

    var body: some View {
        DoubleBezel {
            VStack(spacing: 0) {
                DoubleBezel(innerMaterial: .ultraThin) {
                    SignalHeader(
                        status: status,
                        isPolling: isPolling,
                        refreshBlocked: refreshBlocked,
                        onRefresh: onRefresh
                    )
                }

                ScrollView {
                    panelBodyPlaceholder
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                }
                .frame(minHeight: 180, maxHeight: 420)

                PanelFooter()
            }
        }
        .frame(width: 360)
        .frame(minHeight: 280, maxHeight: 520)
        .panelMotion()
    }

    private var panelBodyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(GHNColor.textSecondary)
            Text("You're caught up")
                .font(GHNFont.emptyHeadline)
                .foregroundStyle(GHNColor.textPrimary)
            Text("New signals will land here when something needs you.")
                .font(GHNFont.meta)
                .foregroundStyle(GHNColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#if DEBUG
#Preview("Fresh") {
    MenuPanelView(
        status: .fresh(lastUpdated: Date().addingTimeInterval(-180)),
        isPolling: true,
        refreshBlocked: false,
        onRefresh: {}
    )
    .padding(16)
    .background(GHNColor.surfaceCanvas)
}

#Preview("Stale") {
    MenuPanelView(
        status: .stale(lastUpdated: Date().addingTimeInterval(-1380)),
        isPolling: false,
        refreshBlocked: false,
        onRefresh: {}
    )
    .padding(16)
    .background(GHNColor.surfaceCanvas)
}

#Preview("Rate limited") {
    MenuPanelView(
        status: .rateLimited(resumesAt: Date().addingTimeInterval(3600)),
        isPolling: false,
        refreshBlocked: true,
        onRefresh: {}
    )
    .padding(16)
    .background(GHNColor.surfaceCanvas)
}
#endif
