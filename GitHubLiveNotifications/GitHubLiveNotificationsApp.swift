import GHNCore
import SwiftUI

@main
struct GitHubLiveNotificationsApp: App {
    @StateObject private var auth = AuthController()
    @State private var inboxItems: [InboxItem] = []
    @State private var panelStatus: PanelStatus = .fresh(lastUpdated: Date())
    @State private var isPolling = false
    @State private var refreshBlocked = false

    var body: some Scene {
        MenuBarExtra("GitHub Live Notifications", systemImage: "bell.fill") {
            RootMenuPanel(
                auth: auth,
                items: $inboxItems,
                status: $panelStatus,
                isPolling: $isPolling,
                refreshBlocked: $refreshBlocked,
                onRefresh: refreshNow
            )
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
    @Binding var items: [InboxItem]
    @Binding var status: PanelStatus
    @Binding var isPolling: Bool
    @Binding var refreshBlocked: Bool
    let onRefresh: () -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuPanelView(
            items: items,
            isUnread: { _ in true },
            status: status,
            isPolling: isPolling,
            refreshBlocked: refreshBlocked,
            onRefresh: onRefresh
        )
        .task {
            await auth.restoreSessionIfNeeded()
            if !auth.isAuthenticated {
                openWindow(id: "pat-setup")
            }
        }
        .onChange(of: auth.isAuthenticated) { isAuthenticated in
            if !isAuthenticated {
                openWindow(id: "pat-setup")
            }
        }
    }
}
