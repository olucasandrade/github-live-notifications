import GHNCore
import SwiftUI

/// Menu-bar shell (T3.1). Full inbox UI lands in M4; this placeholder
/// proves the app target links GHNCore and builds sandboxed + LSUIElement.
@main
struct GitHubLiveNotificationsApp: App {
    var body: some Scene {
        MenuBarExtra("GitHub Live Notifications", systemImage: "bell.fill") {
            DoubleBezel {
                VStack(spacing: 8) {
                    Text("GitHub Live Notifications")
                        .font(GHNFont.panelTitle)
                        .foregroundStyle(GHNColor.textPrimary)
                    Text("Core v\(GHNCoreInfo.version)")
                        .font(GHNFont.mono)
                        .foregroundStyle(GHNColor.textSecondary)
                }
                .padding(12)
            }
            .frame(width: 360)
        }
        .menuBarExtraStyle(.window)
    }
}
