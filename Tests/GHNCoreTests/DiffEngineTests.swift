import XCTest
@testable import GHNCore

final class DiffEngineTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var cache: UserDefaultsCacheStore!
    private var engine: DiffEngine!

    private let repo = MonitoredRepo(owner: "octocat", name: "hello")
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "DiffEngineTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        cache = UserDefaultsCacheStore(defaults: defaults)
        engine = DiffEngine(cache: cache)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    private func thread(id: String, reason: NotificationReason = .mention) -> InboxItem {
        InboxItem(
            id: id,
            title: "Thread \(id)",
            repoFullName: repo.fullName,
            url: URL(string: "https://github.com/\(repo.fullName)/issues/1"),
            source: .thread(reason: reason),
            updatedAt: now
        )
    }

    private func repoItem(id: String, title: String = "New PR") -> InboxItem {
        InboxItem(
            id: id,
            title: title,
            repoFullName: repo.fullName,
            url: URL(string: "https://github.com/\(repo.fullName)/pull/\(id)"),
            source: .synthetic(.newOnMyRepos),
            updatedAt: now
        )
    }

    // MARK: - Notification threads

    func testFirstThreadFetchIsSilentBaseline() {
        let threads = [thread(id: "t1"), thread(id: "t2")]
        XCTAssertEqual(engine.diffThreads(threads), [])
        XCTAssertEqual(Set(cache.threadIDs), ["t1", "t2"])
        XCTAssertTrue(cache.threadsBaselined)
    }

    func testEmptyFirstThreadFetchIsSilentBaselineAndLaterThreadsEmit() {
        XCTAssertEqual(engine.diffThreads([]), [])
        XCTAssertTrue(cache.threadsBaselined)

        let emitted = engine.diffThreads([thread(id: "t1")])
        XCTAssertEqual(emitted.map(\.id), ["t1"])
    }

    func testSecondThreadFetchEmitsOnlyNewThreads() {
        _ = engine.diffThreads([thread(id: "t1"), thread(id: "t2")])

        let emitted = engine.diffThreads([thread(id: "t1"), thread(id: "t2"), thread(id: "t3")])
        XCTAssertEqual(emitted.map(\.id), ["t3"])
        XCTAssertEqual(Set(cache.threadIDs), ["t1", "t2", "t3"])
    }

    func testKnownThreadsAreNotReEmitted() {
        _ = engine.diffThreads([thread(id: "t1")])

        XCTAssertTrue(engine.diffThreads([thread(id: "t1")]).isEmpty)
    }

    // MARK: - PR/issue IDs per repo

    func testFirstRepoItemFetchIsSilentBaseline() {
        let items = [repoItem(id: "42"), repoItem(id: "43")]
        XCTAssertEqual(engine.diffRepoItems(items, forRepo: repo), [])
        XCTAssertEqual(cache.itemIDs(forRepo: repo), ["42", "43"])
        XCTAssertTrue(cache.itemsBaselined(forRepo: repo))
    }

    func testEmptyFirstRepoItemFetchIsSilentBaselineAndLaterItemsEmit() {
        XCTAssertEqual(engine.diffRepoItems([], forRepo: repo), [])
        XCTAssertTrue(cache.itemsBaselined(forRepo: repo))

        let emitted = engine.diffRepoItems([repoItem(id: "1")], forRepo: repo)
        XCTAssertEqual(emitted.map(\.id), ["1"])
    }

    func testSecondRepoItemFetchEmitsOnlyNewIDs() {
        _ = engine.diffRepoItems([repoItem(id: "1"), repoItem(id: "2")], forRepo: repo)

        let emitted = engine.diffRepoItems(
            [repoItem(id: "1"), repoItem(id: "2"), repoItem(id: "3")],
            forRepo: repo
        )
        XCTAssertEqual(emitted.map(\.id), ["3"])
    }

    func testRepoItemBaselinesAreScopedPerRepo() {
        let other = MonitoredRepo(owner: "octocat", name: "world")
        _ = engine.diffRepoItems([repoItem(id: "1")], forRepo: repo)

        XCTAssertEqual(engine.diffRepoItems([repoItem(id: "9")], forRepo: other), [])
        XCTAssertTrue(cache.itemsBaselined(forRepo: other))
    }

    // MARK: - Star counts

    func testFirstStarFetchIsSilentBaseline() {
        XCTAssertNil(engine.diffStarCount(42, forRepo: repo, now: now))
        XCTAssertEqual(cache.starCount(forRepo: repo), 42)
    }

    func testPositiveStarDeltaEmitsSyntheticItem() {
        _ = engine.diffStarCount(100, forRepo: repo, now: now)

        let item = engine.diffStarCount(112, forRepo: repo, now: now)
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.source, .synthetic(.stars))
        XCTAssertEqual(item?.section, .stars)
        XCTAssertEqual(item?.repoFullName, repo.fullName)
        XCTAssertEqual(item?.title, "octocat/hello: +12 stars")
        XCTAssertEqual(cache.starCount(forRepo: repo), 112)
    }

    func testStarDecreaseUpdatesCacheSilently() {
        _ = engine.diffStarCount(100, forRepo: repo, now: now)

        XCTAssertNil(engine.diffStarCount(95, forRepo: repo, now: now))
        XCTAssertEqual(cache.starCount(forRepo: repo), 95)
    }

    func testUnchangedStarCountIsSilent() {
        _ = engine.diffStarCount(50, forRepo: repo, now: now)
        XCTAssertNil(engine.diffStarCount(50, forRepo: repo, now: now))
        XCTAssertEqual(cache.starCount(forRepo: repo), 50)
    }

    func testStarIncreaseAfterDecreaseUsesCurrentBaseline() {
        _ = engine.diffStarCount(100, forRepo: repo, now: now)
        _ = engine.diffStarCount(90, forRepo: repo, now: now)

        let item = engine.diffStarCount(95, forRepo: repo, now: now)
        XCTAssertEqual(item?.title, "octocat/hello: +5 stars")
    }

    func testZeroStarCountIsValidBaseline() {
        XCTAssertNil(engine.diffStarCount(0, forRepo: repo, now: now))
        XCTAssertEqual(cache.starCount(forRepo: repo), 0)

        let item = engine.diffStarCount(3, forRepo: repo, now: now)
        XCTAssertEqual(item?.title, "octocat/hello: +3 stars")
    }
}
