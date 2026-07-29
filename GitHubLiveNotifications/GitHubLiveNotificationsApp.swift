import GHNCore
import SwiftUI

@main
struct GitHubLiveNotificationsApp: App {
    @State private var panelStatus: PanelStatus = .fresh(lastUpdated: Date())
    @State private var isPolling = false
    @State private var refreshBlocked = false

    var body: some Scene {
        MenuBarExtra("GitHub Live Notifications", systemImage: "bell.fill") {
            MenuPanelView(
                status: panelStatus,
                isPolling: isPolling,
                refreshBlocked: refreshBlocked,
                onRefresh: refreshNow
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            Text("Settings")
                .padding()
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
