import GHNCore
import XCTest

/// Acceptance tests for T3.1 app shell configuration. Gives the scheme a real
/// test action (`xcodebuild test` refuses schemes with zero testables).
final class GitHubLiveNotificationsTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testAppProjectLinksGHNCore() {
        XCTAssertFalse(GHNCoreInfo.version.isEmpty)
    }

    func testBundleIdentifierMatchesPlan() throws {
        let project = try String(
            contentsOf: repoRoot.appendingPathComponent("GitHubLiveNotifications.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        XCTAssertTrue(
            project.contains("PRODUCT_BUNDLE_IDENTIFIER = com.lucasandrade.GitHubLiveNotifications;"),
            "App target must use bundle id com.lucasandrade.GitHubLiveNotifications"
        )
    }

    func testEntitlementsEnableSandboxAndNetworkClient() throws {
        let url = repoRoot.appendingPathComponent("GitHubLiveNotifications/GitHubLiveNotifications.entitlements")
        let data = try Data(contentsOf: url)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["com.apple.security.app-sandbox"] as? Bool, true)
        XCTAssertEqual(plist["com.apple.security.network.client"] as? Bool, true)
    }

    func testProjectSetsLSUIElementAccessoryFlag() throws {
        let project = try String(
            contentsOf: repoRoot.appendingPathComponent("GitHubLiveNotifications.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        XCTAssertTrue(
            project.contains("INFOPLIST_KEY_LSUIElement = YES;"),
            "App must be an LSUIElement accessory (no Dock icon)"
        )
    }

    func testAppSourceUsesMenuBarExtraAndPATSetup() throws {
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("GitHubLiveNotifications/GitHubLiveNotificationsApp.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("MenuBarExtra"), "App shell must expose a MenuBarExtra")
        XCTAssertTrue(source.contains(".menuBarExtraStyle(.window)"))
        XCTAssertTrue(source.contains("PATSetupSheet"), "First launch must present PAT setup sheet")
        XCTAssertTrue(source.contains("pat-setup"), "PAT setup window id required for first launch")
    }
}
