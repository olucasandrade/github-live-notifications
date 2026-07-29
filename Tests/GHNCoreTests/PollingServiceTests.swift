import XCTest
@testable import GHNCore

final class PollingServiceTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var cache: UserDefaultsCacheStore!
    private var clock: FakeClock!
    private var client: FakeGitHubPollingClient!
    private var emitted: [[InboxItem]]!
    private var service: PollingService!

    private let repoA = MonitoredRepo(owner: "octocat", name: "a")
    private let repoB = MonitoredRepo(owner: "octocat", name: "b")
    private let repoC = MonitoredRepo(owner: "octocat", name: "c")
    private let repoE = MonitoredRepo(owner: "octocat", name: "e")
    private let repoF = MonitoredRepo(owner: "octocat", name: "f")
    private let repoG = MonitoredRepo(owner: "octocat", name: "g")
    private let repoH = MonitoredRepo(owner: "octocat", name: "h")
    private let repoI = MonitoredRepo(owner: "octocat", name: "i")

    override func setUp() {
        super.setUp()
        suiteName = "PollingServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        cache = UserDefaultsCacheStore(defaults: defaults)
        clock = FakeClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        client = FakeGitHubPollingClient()
        emitted = []
        service = PollingService(
            client: client,
            cache: cache,
            clock: clock,
            jitter: { 15 },
            onItems: { [weak self] items in self?.emitted.append(items) }
        )
    }

    override func tearDown() {
        service.stop()
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Schedule

    func testScheduledTickWaitsBaseIntervalPlusJitter() async {
        let start = clock.now
        service.start(monitoredRepos: [repoA], selfLogin: "octocat")

        for _ in 0..<200 where clock.sleepTargets.isEmpty {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        service.stop()

        XCTAssertEqual(clock.sleepTargets.count, 1)
        XCTAssertEqual(clock.sleepTargets[0], start.addingTimeInterval(PollingSchedule.baseInterval + 15))
    }

    func testJitterIsZeroToThirtySecondsInclusive() {
        var samples: [TimeInterval] = []
        for i in 0..<200 {
            let fraction = Double(i) / 199.0
            samples.append(PollingSchedule.sampleJitter(random: { fraction }))
        }
        XCTAssertEqual(samples.min(), 0)
        XCTAssertEqual(samples.max(), 30)
    }

    // MARK: - X-Poll-Interval

    func testNotificationsRespectPollIntervalFromResponse() async {
        client.notificationResult = .fresh(body: [], etag: nil, pollInterval: 120)

        await service.runScheduledTickForTests()
        XCTAssertEqual(client.notificationCallCount, 1)

        clock.advance(by: 119)
        await service.refreshNow()
        XCTAssertEqual(client.notificationCallCount, 1)

        clock.advance(by: 1)
        await service.refreshNow()
        XCTAssertEqual(client.notificationCallCount, 2)
    }

    func testManualRefreshAlwaysPollsReposEvenWhenNotificationsBlocked() async {
        client.notificationResult = .fresh(body: [], etag: nil, pollInterval: 300)

        await service.runScheduledTickForTests()
        await service.pollReposForTests([repoA, repoB])
        let repoCallsAfterFirst = client.repoMetaCallCount
        let notificationsAfterFirst = client.notificationCallCount
        XCTAssertGreaterThan(repoCallsAfterFirst, 0)

        clock.advance(by: 30)
        await service.refreshNow()

        XCTAssertEqual(client.notificationCallCount, notificationsAfterFirst)
        XCTAssertGreaterThan(client.repoMetaCallCount, repoCallsAfterFirst)
    }

    // MARK: - Concurrency

    func testRepoPollsAreLimitedToFourConcurrent() async {
        client.repoPollDelay = 0.05
        let repos = [repoA, repoB, repoC, repoE, repoF, repoG, repoH, repoI]
        await service.pollReposForTests(repos)
        XCTAssertEqual(client.maxConcurrentRepoPolls, 4)
        XCTAssertEqual(client.repoMetaCallCount, repos.count)
    }

    func testStopCancelsInFlightRepoPolls() async {
        client.repoPollDelay = 1.0
        service.start(monitoredRepos: [repoA, repoB, repoC, repoE, repoF], selfLogin: "octocat")
        try? await Task.sleep(nanoseconds: 50_000_000)
        service.stop()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertLessThan(client.repoMetaCallCount, 5)
        XCTAssertFalse(service.isRunning)
    }

    // MARK: - Diff integration

    func testFirstPollIsSilentBaselineThenSecondEmits() async {
        let baseline = NotificationThread(
            id: "n1",
            reason: .mention,
            subject: .init(title: "First", url: "https://api.github.com/x", type: "Issue"),
            repository: .init(fullName: repoA.fullName),
            updatedAt: clock.now
        )
        let incoming = NotificationThread(
            id: "n2",
            reason: .mention,
            subject: .init(title: "New", url: "https://api.github.com/y", type: "Issue"),
            repository: .init(fullName: repoA.fullName),
            updatedAt: clock.now
        )
        client.notificationResults = [
            .fresh(body: [baseline], etag: nil, pollInterval: nil),
            .fresh(body: [baseline, incoming], etag: nil, pollInterval: nil),
        ]

        await service.runScheduledTickForTests()
        XCTAssertTrue(emitted.allSatisfy(\.isEmpty))

        clock.advance(by: PollingSchedule.baseInterval)
        await service.runScheduledTickForTests()
        XCTAssertEqual(emitted.last?.map(\.id), ["n2"])
    }

    // MARK: - Helpers
}

// MARK: - Fake client

final class FakeGitHubPollingClient: GitHubPollingClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _notificationCallCount = 0
    private var _repoMetaCallCount = 0
    private var _inFlightRepoPolls = 0
    private var _maxConcurrentRepoPolls = 0

    var notificationResult: FetchResult<[NotificationThread]> = .fresh(body: [], etag: nil, pollInterval: nil)
    var notificationResults: [FetchResult<[NotificationThread]>] = []
    var repoPollDelay: TimeInterval = 0

    var notificationCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _notificationCallCount
    }

    var repoMetaCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _repoMetaCallCount
    }

    var maxConcurrentRepoPolls: Int {
        lock.lock()
        defer { lock.unlock() }
        return _maxConcurrentRepoPolls
    }

    var inFlightWork: Int {
        lock.lock()
        defer { lock.unlock() }
        return _inFlightRepoPolls
    }

    func fetchNotifications() async throws -> FetchResult<[NotificationThread]> {
        lock.lock()
        _notificationCallCount += 1
        let count = _notificationCallCount
        lock.unlock()
        if !notificationResults.isEmpty {
            let index = min(count - 1, notificationResults.count - 1)
            return notificationResults[index]
        }
        return notificationResult
    }

    func fetchRepo(owner: String, name: String) async throws -> FetchResult<GitHubRepository> {
        lock.lock()
        _repoMetaCallCount += 1
        _inFlightRepoPolls += 1
        if _inFlightRepoPolls > _maxConcurrentRepoPolls {
            _maxConcurrentRepoPolls = _inFlightRepoPolls
        }
        lock.unlock()

        if repoPollDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(repoPollDelay * 1_000_000_000))
        }

        lock.lock()
        _inFlightRepoPolls -= 1
        lock.unlock()

        let repo = GitHubRepository(
            id: 1,
            name: name,
            fullName: "\(owner)/\(name)",
            owner: .init(login: owner),
            fork: false,
            archived: false,
            isPrivate: false,
            stargazersCount: 10
        )
        return .fresh(body: repo, etag: nil, pollInterval: nil)
    }

    func fetchPulls(owner: String, name: String) async throws -> FetchResult<[PullRequestSummary]> {
        .fresh(body: [], etag: nil, pollInterval: nil)
    }

    func fetchIssues(owner: String, name: String) async throws -> FetchResult<[IssueSummary]> {
        .fresh(body: [], etag: nil, pollInterval: nil)
    }
}
