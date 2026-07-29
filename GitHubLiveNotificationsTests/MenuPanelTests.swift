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

    // MARK: - Sectioned inbox list (UI-SPEC §2.2, T4.3)

    func testInboxListDefinesFiveSectionsInPlanOrder() throws {
        let source = try appSource(at: "Panel/InboxSection+Display.swift")
        for title in [
            "My work",
            "Activity",
            "CI & security",
            "New on my repos",
            "Stars",
        ] {
            XCTAssertTrue(source.contains(title), "Missing section title \"\(title)\"")
        }
        XCTAssertTrue(source.contains("InboxSection.allCases"), "Sections must follow InboxSection order")
    }

    func testInboxListHidesEmptySections() throws {
        let source = try appSource(at: "Panel/InboxListLayout.swift")
        XCTAssertTrue(source.contains("isEmpty"), "Empty sections must be hidden")
    }

    func testInboxListCapsAtTwentyRowsWithMoreFooter() throws {
        let layoutSource = try appSource(at: "Panel/InboxListLayout.swift")
        XCTAssertTrue(layoutSource.contains("20"), "Inbox must cap visible rows at 20")
        let listSource = try appSource(at: "Components/InboxListView.swift")
        XCTAssertTrue(listSource.contains("more on GitHub"), "Overflow footer must link to GitHub")
    }

    func testInboxRowUsesUISpecAnatomy() throws {
        let source = try appSource(at: "Components/InboxRowView.swift")
        XCTAssertTrue(source.contains("GHNFont.rowTitle"), "Row title uses UI-SPEC row font")
        XCTAssertTrue(source.contains("GHNFont.meta"), "Meta line uses UI-SPEC meta font")
        XCTAssertTrue(source.contains("GHNFont.mono"), "Relative time uses SF Mono")
        XCTAssertTrue(source.contains("accentSignal"), "Unread pip uses accent color")
        XCTAssertTrue(source.contains("repoFullName"), "Meta includes repo full name")
    }

    func testInboxSectionHeaderUsesMonoCount() throws {
        let source = try appSource(at: "Components/InboxSectionHeader.swift")
        XCTAssertTrue(source.contains("GHNFont.panelTitle"), "Section title uses panel title font")
        XCTAssertTrue(source.contains("GHNFont.mono"), "Section count uses SF Mono")
    }

    func testInboxEmptyStateShowsCaughtUp() throws {
        let source = try appSource(at: "Components/InboxEmptyState.swift")
        XCTAssertTrue(source.contains("bell.slash"), "Empty state uses bell.slash symbol")
        XCTAssertTrue(source.contains("You're caught up"), "Empty state headline required")
        XCTAssertTrue(
            source.contains("New signals will land here when something needs you."),
            "Empty state subcopy required"
        )
    }

    func testMenuPanelBindsInboxItems() throws {
        let panelSource = try appSource(at: "Panel/MenuPanelView.swift")
        XCTAssertTrue(panelSource.contains("InboxListView"), "Panel body must render InboxListView")
        XCTAssertTrue(panelSource.contains("items:"), "MenuPanelView must accept inbox items")
        let appSource = try appSource(at: "GitHubLiveNotificationsApp.swift")
        XCTAssertTrue(appSource.contains("InboxController"), "App must hold inbox state via InboxController")
    }

    // MARK: - Badge, URL open, mark read (UI-SPEC §2.5 / §2.2, T4.4)

    func testMenuBarBadgeCapsAt99Plus() throws {
        let formatSource = try appSource(at: "Design/MenuBarBadgeFormat.swift")
        XCTAssertTrue(formatSource.contains("99+"), "Badge must cap display at 99+")
        let labelSource = try appSource(at: "Design/MenuBarBadgeLabel.swift")
        XCTAssertTrue(labelSource.contains("MenuBarBadgeFormat"), "Menu bar label must use badge formatter")
        let appSource = try appSource(at: "GitHubLiveNotificationsApp.swift")
        XCTAssertTrue(appSource.contains("MenuBarBadgeLabel"), "App must render badge on MenuBarExtra label")
    }

    func testInboxRowOpensResolvedURLInBrowser() throws {
        let rowSource = try appSource(at: "Components/InboxRowView.swift")
        XCTAssertTrue(rowSource.contains("onOpen"), "Row must accept open action")
        XCTAssertTrue(rowSource.contains("onTapGesture") || rowSource.contains("Button"), "Row must handle click")
        let controllerSource = try appSource(at: "InboxController.swift")
        XCTAssertTrue(controllerSource.contains("openInBrowser"), "Controller must open resolved html_url")
        XCTAssertTrue(controllerSource.contains("ThreadHTMLURLResolver"), "Controller must use URL resolver")
    }

    func testInboxRowMarkReadContextMenu() throws {
        let rowSource = try appSource(at: "Components/InboxRowView.swift")
        XCTAssertTrue(rowSource.contains("Mark read"), "Thread rows need Mark read action")
        XCTAssertTrue(rowSource.contains("contextMenu"), "Mark read belongs in context menu")
        let controllerSource = try appSource(at: "InboxController.swift")
        XCTAssertTrue(controllerSource.contains("InboxActions"), "Controller must wire InboxActions")
        XCTAssertTrue(controllerSource.contains("markRead"), "Controller must call markRead")
    }

    func testMarkAllReadWiredToCore() throws {
        let panelSource = try appSource(at: "Panel/MenuPanelView.swift")
        XCTAssertTrue(panelSource.contains("onMarkAllRead"), "Panel must expose mark-all action")
        let controllerSource = try appSource(at: "InboxController.swift")
        XCTAssertTrue(controllerSource.contains("markAllRead"), "Controller must call markAllRead")
    }
}
