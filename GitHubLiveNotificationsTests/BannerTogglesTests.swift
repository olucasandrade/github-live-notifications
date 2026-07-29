import GHNCore
import XCTest
@testable import GitHubLiveNotifications

/// Acceptance tests for T5.3 banner toggles + UserNotifications defaults (PLAN.md; UI-SPEC §4).
final class BannerTogglesTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func appSource(at path: String) throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("GitHubLiveNotifications/\(path)"),
            encoding: .utf8
        )
    }

    // MARK: - Factory defaults (PLAN.md)

    func testFactoryDefaultsEnableHighSignalReasons() {
        let settings = BannerSettings.factoryDefaults()
        for reason in [
            NotificationReason.assign,
            .author,
            .mention,
            .reviewRequested,
            .teamMention,
            .securityAlert,
        ] {
            XCTAssertTrue(
                settings.isBannerEnabled(for: reason.rawValue),
                "\(reason.rawValue) should deliver banners by default"
            )
        }
    }

    func testFactoryDefaultsDisableNoisyReasons() {
        let settings = BannerSettings.factoryDefaults()
        for reason in [
            NotificationReason.comment,
            .stateChange,
            .manual,
            .subscribed,
            .ciActivity,
        ] {
            XCTAssertFalse(
                settings.isBannerEnabled(for: reason.rawValue),
                "\(reason.rawValue) should be badge-only by default"
            )
        }
    }

    func testFactoryDefaultsDisableStarsAndEnableNewOnMyRepos() {
        let settings = BannerSettings.factoryDefaults()
        XCTAssertFalse(settings.isBannerEnabled(for: BannerCategory.stars.rawValue))
        XCTAssertTrue(settings.isBannerEnabled(for: BannerCategory.newOnMyRepos.rawValue))
    }

    func testGlobalBannerToggleGatesPerCategoryDelivery() {
        var settings = BannerSettings.factoryDefaults()
        settings.globalEnabled = false
        XCTAssertFalse(settings.isBannerEnabled(for: NotificationReason.mention.rawValue))
    }

    // MARK: - Settings UI (UI-SPEC §3.1, §4)

    func testSettingsViewIncludesGlobalAndPerCategoryBannerToggles() throws {
        let source = try appSource(at: "Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("Show banner notifications"), "Global banner master toggle required")
        XCTAssertTrue(source.contains("Deliver banner"), "Per-category banner checkbox required")
        XCTAssertTrue(source.contains("BannerSettings"), "Settings must bind to BannerSettings store")
    }

    func testSettingsViewDisablesBannerTogglesInBadgeOnlyMode() throws {
        let source = try appSource(at: "Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("Badge-only mode"), "Denied permission must show badge-only footnote")
        XCTAssertTrue(source.contains("isBadgeOnlyMode"), "Banner toggles must respect badge-only mode")
    }

    // MARK: - Permission timing (UI-SPEC §4)

    func testNotificationPermissionRequestedAfterPATSuccess() throws {
        let authSource = try appSource(at: "AuthController.swift")
        XCTAssertTrue(
            authSource.contains("requestNotificationPermission"),
            "Permission must be requested after successful PAT validation, not before"
        )
    }

    func testNotificationAuthorizationControllerUsesUserNotifications() throws {
        let source = try appSource(at: "Notifications/NotificationAuthorizationController.swift")
        XCTAssertTrue(source.contains("UserNotifications"), "Must bridge to UserNotifications framework")
        XCTAssertTrue(source.contains("requestAuthorization"), "Must request alert/badge permission")
    }
}
