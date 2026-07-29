import XCTest

/// Acceptance tests for T5.1 Settings window groups (UI-SPEC §3).
final class SettingsWindowTests: XCTestCase {
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

    // MARK: - Window size (UI-SPEC §3)

    func testSettingsViewUses520By640Frame() throws {
        let source = try appSource(at: "Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("520"), "Settings width must be 520")
        XCTAssertTrue(source.contains("640"), "Settings height must be 640")
    }

    // MARK: - Structure (UI-SPEC §3.1)

    func testSettingsViewUsesDoubleBezelFormGroups() throws {
        let source = try appSource(at: "Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("DoubleBezel"), "Each settings group must use double-bezel chrome")
        XCTAssertTrue(source.contains("Form"), "Settings must use a Form layout")
    }

    func testSettingsViewIncludesAllUISpecGroups() throws {
        let source = try appSource(at: "Settings/SettingsView.swift")
        for group in [
            "Account",
            "Repositories",
            "Notification types",
            "Banners",
            "Noise",
            "General",
            "About",
        ] {
            XCTAssertTrue(source.contains(group), "Missing settings group \"\(group)\"")
        }
    }

    // MARK: - Account (UI-SPEC §3.1)

    func testAccountGroupShowsSignedInLogin() throws {
        let source = try appSource(at: "Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("Signed in as"), "Account must show signed-in copy")
        XCTAssertTrue(source.contains("login"), "Account must bind to auth login")
        XCTAssertTrue(source.contains("Replace token"), "Account must offer Replace token")
        XCTAssertTrue(source.contains("Sign out"), "Account must offer Sign out")
        XCTAssertTrue(source.contains(".destructive"), "Sign out must use destructive role")
    }

    // MARK: - Brand + accent (UI-SPEC §1.1–§1.2)

    func testSettingsHeaderUsesSFRoundedBrand() throws {
        let source = try appSource(at: "Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("GHNFont.brand"), "Settings header must use brand font token")
    }

    func testSettingsViewUsesSignalGreenAccent() throws {
        let source = try appSource(at: "Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("accentSignal"), "Settings must use signal-green accent")
    }

    func testAboutShowsDevVersionAndReleasesLink() throws {
        let source = try appSource(at: "Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("1.0.0-dev"), "About must show dev version string")
        XCTAssertTrue(source.contains("Releases"), "About must link to GitHub Releases")
    }

    // MARK: - App wiring

    func testAppWiresSettingsViewInSettingsScene() throws {
        let source = try appSource(at: "GitHubLiveNotificationsApp.swift")
        XCTAssertTrue(source.contains("SettingsView"), "App must render SettingsView in Settings scene")
    }
}
