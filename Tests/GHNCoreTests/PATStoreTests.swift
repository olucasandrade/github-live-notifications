import Security
import XCTest
@testable import GHNCore

final class PATStoreTests: XCTestCase {

    private var suiteService: String!
    private var store: KeychainPATStore!

    override func setUp() {
        super.setUp()
        suiteService = "com.lucasandrade.GitHubLiveNotifications.pat.test.\(UUID().uuidString)"
        store = KeychainPATStore(service: suiteService, account: "pat")
        try? store.delete()
    }

    override func tearDown() {
        try? store.delete()
        super.tearDown()
    }

    // MARK: - Plan constants

    func testProductionServiceMatchesPlan() {
        XCTAssertEqual(
            KeychainPATStore.service,
            "com.lucasandrade.GitHubLiveNotifications.pat"
        )
    }

    func testSaveQueryUsesWhenUnlockedAccessibility() {
        let attrs = KeychainPATStore.saveAttributes(
            token: "ghp_example",
            service: KeychainPATStore.service,
            account: "pat"
        )
        XCTAssertEqual(
            attrs[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleWhenUnlocked as String
        )
        XCTAssertEqual(
            attrs[kSecAttrService as String] as? String,
            KeychainPATStore.service
        )
    }

    // MARK: - Round-trip

    func testLoadReturnsNilWhenEmpty() throws {
        XCTAssertNil(try store.load())
    }

    func testSaveLoadDeleteRoundTrip() throws {
        let token = "ghp_roundtrip_\(UUID().uuidString)"

        try store.save(token)
        XCTAssertEqual(try store.load(), token)

        try store.delete()
        XCTAssertNil(try store.load())
    }

    func testSaveReplacesExistingToken() throws {
        try store.save("ghp_first")
        try store.save("ghp_second")
        XCTAssertEqual(try store.load(), "ghp_second")
    }

    func testDeleteIsIdempotentWhenEmpty() throws {
        try store.delete()
        try store.delete()
        XCTAssertNil(try store.load())
    }

    func testStateSurvivesNewInstanceOverSameService() throws {
        let token = "ghp_persist_\(UUID().uuidString)"
        try store.save(token)

        let reloaded = KeychainPATStore(service: suiteService, account: "pat")
        XCTAssertEqual(try reloaded.load(), token)
    }
}
