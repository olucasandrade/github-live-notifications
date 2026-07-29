import GHNCore
import SwiftUI

/// Menu-bar shell (T3.1). Full inbox UI lands in M4; this is a placeholder
/// proving the app target links GHNCore and builds sandboxed + LSUIElement.
@main
struct GitHubLiveNotificationsApp: App {
    var body: some Scene {
        MenuBarExtra("GitHub Live Notifications", systemImage: "bell.badge") {
            VStack(spacing: 8) {
                Text("GitHub Live Notifications")
                    .font(.headline)
                Text("Core v\(GHNCoreInfo.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(width: 260)
        }
        .menuBarExtraStyle(.window)
    }
}
