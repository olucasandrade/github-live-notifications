import GHNCore
import SwiftUI

/// MenuBarExtra `.window` panel shell (UI-SPEC §2).
struct MenuPanelView: View {
    var items: [InboxItem]
    var isUnread: (InboxItem) -> Bool
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
                    InboxListView(items: items, isUnread: isUnread)
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
}

#if DEBUG
#Preview("Empty") {
    MenuPanelView(
        items: [],
        isUnread: { _ in false },
        status: .fresh(lastUpdated: Date().addingTimeInterval(-180)),
        isPolling: true,
        refreshBlocked: false,
        onRefresh: {}
    )
    .padding(16)
    .background(GHNColor.surfaceCanvas)
}

#Preview("With items") {
    MenuPanelView(
        items: [
            InboxItem(
                id: "1",
                title: "Fix notification polling jitter",
                repoFullName: "owner/repo",
                url: nil,
                source: .thread(reason: .mention),
                updatedAt: Date().addingTimeInterval(-120)
            ),
            InboxItem(
                id: "2",
                title: "Add sectioned inbox list",
                repoFullName: "owner/app",
                url: nil,
                source: .thread(reason: .reviewRequested),
                updatedAt: Date().addingTimeInterval(-3600)
            ),
        ],
        isUnread: { $0.id == "1" },
        status: .fresh(lastUpdated: Date().addingTimeInterval(-180)),
        isPolling: false,
        refreshBlocked: false,
        onRefresh: {}
    )
    .padding(16)
    .background(GHNColor.surfaceCanvas)
}

#Preview("Stale") {
    MenuPanelView(
        items: [],
        isUnread: { _ in false },
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
        items: [],
        isUnread: { _ in false },
        status: .rateLimited(resumesAt: Date().addingTimeInterval(3600)),
        isPolling: false,
        refreshBlocked: true,
        onRefresh: {}
    )
    .padding(16)
    .background(GHNColor.surfaceCanvas)
}
#endif
