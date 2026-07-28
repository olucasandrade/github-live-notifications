import XCTest
@testable import GHNCore

final class GHNCoreInfoTests: XCTestCase {
    func testVersionIsNonEmpty() {
        XCTAssertFalse(GHNCoreInfo.version.isEmpty)
    }
}
