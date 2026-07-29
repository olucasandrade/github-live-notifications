import GHNCore
import SwiftUI

@main
struct GitHubLiveNotificationsApp: App {
    @StateObject private var auth = AuthController()

    var body: some Scene {
        MenuBarExtra("GitHub Live Notifications", systemImage: "bell.badge") {
            MenuBarPanel(auth: auth)
        }
        .menuBarExtraStyle(.window)

        Window("GitHub Live Notifications", id: "pat-setup") {
            PATSetupSheet(auth: auth)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

/// Menu-bar panel placeholder until M4 inbox UI lands.
private struct MenuBarPanel: View {
    @ObservedObject var auth: AuthController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 8) {
            Text("GitHub Live Notifications")
                .font(.headline)
            if let login = auth.login {
                Text("Signed in as \(login)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Core v\(GHNCoreInfo.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 260)
        .task {
            await auth.restoreSessionIfNeeded()
            if !auth.isAuthenticated {
                openWindow(id: "pat-setup")
            }
        }
    }
}
