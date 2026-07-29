import XCTest

/// Acceptance tests for T4.2 MenuBarExtra window header + footer (UI-SPEC §2).
final class MenuPanelTests: XCTestCase {
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

    // MARK: - Panel size (UI-SPEC §2)

    func testMenuPanelUses360WidthAndHeightBounds() throws {
        let source = try appSource(at: "Panel/MenuPanelView.swift")
        XCTAssertTrue(source.contains("360"), "Panel width must be 360")
        XCTAssertTrue(source.contains("280"), "Panel min height must be 280")
        XCTAssertTrue(source.contains("520"), "Panel max height must be 520")
    }

    // MARK: - Header signal strip (UI-SPEC §2.1)

    func testSignalHeaderIncludesPipRelativeTimeAndRefresh() throws {
        let source = try appSource(at: "Components/SignalHeader.swift")
        XCTAssertTrue(source.contains("accentSignal"), "Signal pip must use accent color")
        XCTAssertTrue(source.contains("arrow.clockwise"), "Refresh control required")
        XCTAssertTrue(source.contains("isPolling"), "Pip breathes while polling")
        XCTAssertTrue(source.contains("accessibilityReduceMotion"), "Reduce motion disables pip breathe")
    }

    func testPanelStatusCoversStaleErrorAndRateLimitCopy() throws {
        let source = try appSource(at: "Panel/PanelStatus.swift")
        for phrase in [
            "Updated",
            "Stale",
            "Invalid token",
            "Rate limited",
            "resumes",
        ] {
            XCTAssertTrue(source.contains(phrase), "Missing status copy for \"\(phrase)\"")
        }
    }

    func testSignalHeaderDisablesRefreshWhenBlocked() throws {
        let source = try appSource(at: "Components/SignalHeader.swift")
        XCTAssertTrue(source.contains("refreshBlocked"), "Refresh must respect poll-interval block")
        XCTAssertTrue(source.contains("disabled"), "Refresh button disables when blocked")
    }

    // MARK: - Footer (UI-SPEC §2.3)

    func testPanelFooterIncludesOpenGitHubSettingsAndQuit() throws {
        let source = try appSource(at: "Components/PanelFooter.swift")
        XCTAssertTrue(source.contains("Open GitHub"), "Footer must include Open GitHub")
        XCTAssertTrue(source.contains("Settings"), "Footer must include Settings")
        XCTAssertTrue(source.contains("Quit"), "Footer must include Quit")
        XCTAssertTrue(source.contains("surfaceHairline"), "Footer must have hairline separator")
    }

    // MARK: - Motion (UI-SPEC §1.4)

    func testPanelMotionUsesSpringOpenAndReduceMotionFallback() throws {
        let source = try appSource(at: "Components/PanelMotion.swift")
        XCTAssertTrue(source.contains("0.32"), "Spring response must be 0.32")
        XCTAssertTrue(source.contains("0.86"), "Spring damping must be 0.86")
        XCTAssertTrue(source.contains("12"), "Panel open rise must be 12pt")
        XCTAssertTrue(source.contains("accessibilityReduceMotion"), "Reduce motion must fall back to opacity only")
    }

    // MARK: - App wiring

    func testAppUsesMenuPanelViewInWindowStyle() throws {
        let source = try appSource(at: "GitHubLiveNotificationsApp.swift")
        XCTAssertTrue(source.contains("MenuPanelView"), "App must render MenuPanelView")
        XCTAssertTrue(source.contains(".menuBarExtraStyle(.window)"))
    }
}
