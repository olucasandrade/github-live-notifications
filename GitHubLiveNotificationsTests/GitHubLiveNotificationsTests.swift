import GHNCore
import XCTest

/// Smoke test giving the app scheme a real test action (`xcodebuild test`
/// refuses schemes with zero testables). Also proves the app project
/// resolves and links the local GHNCore package outside SPM.
final class GitHubLiveNotificationsTests: XCTestCase {
    func testAppProjectLinksGHNCore() {
        XCTAssertFalse(GHNCoreInfo.version.isEmpty)
    }
}
