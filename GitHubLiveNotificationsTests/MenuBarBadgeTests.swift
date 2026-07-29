import GHNCore
@testable import GitHubLiveNotifications
import XCTest

/// Behavioral tests for menu bar badge formatting (UI-SPEC §2.5).
final class MenuBarBadgeTests: XCTestCase {
    func testDisplayReturnsNilForZeroUnread() {
        XCTAssertNil(MenuBarBadgeFormat.display(count: 0))
    }

    func testDisplayShowsExactCountUpTo99() {
        XCTAssertEqual(MenuBarBadgeFormat.display(count: 1), "1")
        XCTAssertEqual(MenuBarBadgeFormat.display(count: 42), "42")
        XCTAssertEqual(MenuBarBadgeFormat.display(count: 99), "99")
    }

    func testDisplayCapsAt99Plus() {
        XCTAssertEqual(MenuBarBadgeFormat.display(count: 100), "99+")
        XCTAssertEqual(MenuBarBadgeFormat.display(count: 500), "99+")
    }
}
