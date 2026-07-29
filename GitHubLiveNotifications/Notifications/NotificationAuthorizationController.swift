import Foundation
import UserNotifications

/// Abstraction over `UNUserNotificationCenter` for tests and live permission flow.
protocol NotificationCenterClient: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

struct LiveNotificationCenterClient: NotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }
}

/// Tracks macOS notification permission and exposes badge-only mode (UI-SPEC §4).
@MainActor
final class NotificationAuthorizationController: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center: NotificationCenterClient

    init(center: NotificationCenterClient = LiveNotificationCenterClient()) {
        self.center = center
    }

    var isBadgeOnlyMode: Bool {
        authorizationStatus == .denied
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.authorizationStatus()
    }

    /// Request alert + badge permission after successful PAT validation (UI-SPEC §4).
    func requestNotificationPermission() async {
        _ = try? await center.requestAuthorization(options: [.alert, .badge])
        await refreshAuthorizationStatus()
    }
}
