import XCTest
@testable import GHNCore

final class CacheStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: UserDefaultsCacheStore!

    private let repoA = MonitoredRepo(owner: "octocat", name: "a")
    private let repoB = MonitoredRepo(owner: "octocat", name: "b")

    override func setUp() {
        super.setUp()
        suiteName = "CacheStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = UserDefaultsCacheStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Thread IDs

    func testThreadIDsStartEmpty() {
        XCTAssertEqual(store.threadIDs, [])
    }

    func testRecordThreadIDsKeepsInsertionOrder() {
        store.recordThreadIDs(["t1", "t2", "t3"])
        XCTAssertEqual(store.threadIDs, ["t1", "t2", "t3"])
    }

    func testRecordThreadIDsDeduplicatesWithoutReordering() {
        store.recordThreadIDs(["t1", "t2", "t3"])
        store.recordThreadIDs(["t2", "t4"])
        XCTAssertEqual(store.threadIDs, ["t1", "t2", "t3", "t4"])
    }

    func testThreadIDsFIFOCappedAt1000() {
        store.recordThreadIDs((1...1000).map { "t\($0)" })
        XCTAssertEqual(store.threadIDs.count, 1000)

        store.recordThreadIDs(["t1001", "t1002"])
        XCTAssertEqual(store.threadIDs.count, 1000)
        XCTAssertEqual(store.threadIDs.first, "t3") // t1, t2 evicted oldest-first
        XCTAssertEqual(store.threadIDs.last, "t1002")
        XCTAssertFalse(store.threadIDs.contains("t1"))
    }

    func testThreadIDCapAppliesToSingleLargeBatch() {
        store.recordThreadIDs((1...1500).map { "t\($0)" })
        XCTAssertEqual(store.threadIDs.count, 1000)
        XCTAssertEqual(store.threadIDs.first, "t501")
        XCTAssertEqual(store.threadIDs.last, "t1500")
    }

    // MARK: - PR/issue item IDs per repo

    func testItemIDsStartEmptyPerRepo() {
        XCTAssertEqual(store.itemIDs(forRepo: repoA), [])
    }

    func testRecordItemIDsAreScopedPerRepo() {
        store.recordItemIDs(["1", "2"], forRepo: repoA)
        store.recordItemIDs(["3"], forRepo: repoB)
        XCTAssertEqual(store.itemIDs(forRepo: repoA), ["1", "2"])
        XCTAssertEqual(store.itemIDs(forRepo: repoB), ["3"])
    }

    func testRecordItemIDsDeduplicates() {
        store.recordItemIDs(["1", "2"], forRepo: repoA)
        store.recordItemIDs(["2", "3"], forRepo: repoA)
        XCTAssertEqual(store.itemIDs(forRepo: repoA), ["1", "2", "3"])
    }

    func testItemIDsFIFOCappedAt200PerRepo() {
        store.recordItemIDs((1...200).map(String.init), forRepo: repoA)
        store.recordItemIDs(["201", "202"], forRepo: repoA)

        let ids = store.itemIDs(forRepo: repoA)
        XCTAssertEqual(ids.count, 200)
        XCTAssertFalse(ids.contains("1"))
        XCTAssertFalse(ids.contains("2"))
        XCTAssertTrue(ids.contains("3"))
        XCTAssertTrue(ids.contains("201"))
        XCTAssertTrue(ids.contains("202"))
    }

    func testItemIDCapIsPerRepoNotGlobal() {
        store.recordItemIDs((1...250).map(String.init), forRepo: repoA)
        store.recordItemIDs(["1", "2"], forRepo: repoB)
        XCTAssertEqual(store.itemIDs(forRepo: repoB), ["1", "2"])
    }

    // MARK: - Star counts

    func testStarCountStartsAbsent() {
        XCTAssertNil(store.starCount(forRepo: repoA))
    }

    func testRecordStarCountRoundTrips() {
        store.recordStarCount(42, forRepo: repoA)
        XCTAssertEqual(store.starCount(forRepo: repoA), 42)
    }

    func testStarCountZeroIsRecordedNotAbsent() {
        store.recordStarCount(0, forRepo: repoA)
        XCTAssertEqual(store.starCount(forRepo: repoA), 0)
    }

    func testStarCountsAreScopedPerRepo() {
        store.recordStarCount(10, forRepo: repoA)
        store.recordStarCount(20, forRepo: repoB)
        XCTAssertEqual(store.starCount(forRepo: repoA), 10)
        XCTAssertEqual(store.starCount(forRepo: repoB), 20)
    }

    // MARK: - ETags

    func testETagStartsAbsent() {
        XCTAssertNil(store.etag(forKey: "notifications"))
    }

    func testRecordETagRoundTrips() {
        store.recordETag(#""abc123""#, forKey: "notifications")
        XCTAssertEqual(store.etag(forKey: "notifications"), #""abc123""#)
    }

    func testRecordETagNilClears() {
        store.recordETag(#""abc""#, forKey: "notifications")
        store.recordETag(nil, forKey: "notifications")
        XCTAssertNil(store.etag(forKey: "notifications"))
    }

    func testETagsAreScopedPerKey() {
        store.recordETag(#""a""#, forKey: "notifications")
        store.recordETag(#""b""#, forKey: "stars:octocat/a")
        XCTAssertEqual(store.etag(forKey: "notifications"), #""a""#)
        XCTAssertEqual(store.etag(forKey: "stars:octocat/a"), #""b""#)
    }

    // MARK: - Wipe on unselect repo (PLAN.md: Cache)

    func testWipeRepoClearsItemIDsAndStarCount() {
        store.recordItemIDs(["1", "2"], forRepo: repoA)
        store.recordStarCount(42, forRepo: repoA)
        store.markItemsBaselined(forRepo: repoA)

        store.wipeRepo(repoA)

        XCTAssertEqual(store.itemIDs(forRepo: repoA), [])
        XCTAssertNil(store.starCount(forRepo: repoA))
        XCTAssertFalse(store.itemsBaselined(forRepo: repoA))
    }

    func testWipeRepoLeavesOtherReposAndGlobalStateIntact() {
        store.recordThreadIDs(["t1"])
        store.recordItemIDs(["1"], forRepo: repoA)
        store.recordItemIDs(["9"], forRepo: repoB)
        store.recordStarCount(7, forRepo: repoB)
        store.recordETag(#""e""#, forKey: "notifications")

        store.wipeRepo(repoA)

        XCTAssertEqual(store.threadIDs, ["t1"])
        XCTAssertEqual(store.itemIDs(forRepo: repoB), ["9"])
        XCTAssertEqual(store.starCount(forRepo: repoB), 7)
        XCTAssertEqual(store.etag(forKey: "notifications"), #""e""#)
    }

    // MARK: - Wipe all (sign-out, PLAN.md: Cache)

    func testWipeAllClearsEverything() {
        store.recordThreadIDs(["t1"])
        store.markThreadsBaselined()
        store.recordItemIDs(["1"], forRepo: repoA)
        store.markItemsBaselined(forRepo: repoA)
        store.recordStarCount(42, forRepo: repoA)
        store.recordETag(#""e""#, forKey: "notifications")

        store.wipeAll()

        XCTAssertEqual(store.threadIDs, [])
        XCTAssertFalse(store.threadsBaselined)
        XCTAssertEqual(store.itemIDs(forRepo: repoA), [])
        XCTAssertFalse(store.itemsBaselined(forRepo: repoA))
        XCTAssertNil(store.starCount(forRepo: repoA))
        XCTAssertNil(store.etag(forKey: "notifications"))
    }

    // MARK: - Persistence

    func testStateSurvivesNewInstanceOverSameDefaults() {
        store.recordThreadIDs(["t1"])
        store.recordItemIDs(["1"], forRepo: repoA)
        store.recordStarCount(42, forRepo: repoA)
        store.recordETag(#""e""#, forKey: "notifications")

        let reloaded = UserDefaultsCacheStore(defaults: defaults)
        XCTAssertEqual(reloaded.threadIDs, ["t1"])
        XCTAssertEqual(reloaded.itemIDs(forRepo: repoA), ["1"])
        XCTAssertEqual(reloaded.starCount(forRepo: repoA), 42)
        XCTAssertEqual(reloaded.etag(forKey: "notifications"), #""e""#)
    }
}
