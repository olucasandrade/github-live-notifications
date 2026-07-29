import SwiftUI

/// MenuBarExtra label with unread badge (UI-SPEC §2.5).
struct MenuBarBadgeLabel: View {
    let unreadCount: Int

    var body: some View {
        Label {
            Text("GitHub Live Notifications")
        } icon: {
            Image(systemName: "bell.fill")
        }
        .badge(MenuBarBadgeFormat.display(count: unreadCount))
    }
}
