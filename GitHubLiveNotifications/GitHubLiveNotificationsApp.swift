import GHNCore
import SwiftUI

@main
struct GitHubLiveNotificationsApp: App {
    @StateObject private var auth = AuthController()
    @StateObject private var inbox = InboxController()
    @State private var panelStatus: PanelStatus = .fresh(lastUpdated: Date())
    @State private var isPolling = false
    @State private var refreshBlocked = false

    var body: some Scene {
        MenuBarExtra {
            RootMenuPanel(
                auth: auth,
                inbox: inbox,
                status: $panelStatus,
                isPolling: $isPolling,
                refreshBlocked: $refreshBlocked,
                onRefresh: refreshNow
            )
        } label: {
            MenuBarBadgeLabel(unreadCount: inbox.unreadCount)
        }
        .menuBarExtraStyle(.window)

        Window("GitHub Live Notifications", id: "pat-setup") {
            PATSetupSheet(auth: auth)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView(auth: auth)
        }
    }

    private func refreshNow() {
        isPolling = true
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                panelStatus = .fresh(lastUpdated: Date())
                isPolling = false
            }
        }
    }
}

/// Hosts the menu panel and opens the PAT sheet on first launch when needed.
private struct RootMenuPanel: View {
    @ObservedObject var auth: AuthController
    @ObservedObject var inbox: InboxController
    @Binding var status: PanelStatus
    @Binding var isPolling: Bool
    @Binding var refreshBlocked: Bool
    let onRefresh: () -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuPanelView(
            items: inbox.items,
            isUnread: inbox.isUnread,
            status: status,
            isPolling: isPolling,
            refreshBlocked: refreshBlocked,
            onRefresh: onRefresh,
            onOpen: inbox.openInBrowser,
            onMarkRead: inbox.markRead,
            onMarkAllRead: inbox.markAllRead
        )
        .task {
            await auth.restoreSessionIfNeeded()
            await configureInboxIfNeeded()
            if !auth.isAuthenticated {
                openWindow(id: "pat-setup")
            }
        }
        .onChange(of: auth.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                Task { await configureInboxIfNeeded() }
            } else {
                inbox.configure(token: nil)
                inbox.replaceItems([])
                openWindow(id: "pat-setup")
            }
        }
    }

    private func configureInboxIfNeeded() async {
        guard auth.isAuthenticated else { return }
        let store = KeychainPATStore()
        let token = try? store.load()
        inbox.configure(token: token)
    }
}
