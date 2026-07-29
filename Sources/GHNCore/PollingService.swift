import Foundation

/// Scheduling constants (PLAN.md: Polling).
public enum PollingSchedule {
    public static let baseInterval: TimeInterval = 600
    public static let maxJitter: TimeInterval = 30
    public static let maxConcurrentRepoPolls = 4

    /// Default jitter for scheduled ticks: uniform 0…30 s.
    public static func sampleJitter(random: () -> Double = { Double.random(in: 0...1) }) -> TimeInterval {
        random() * maxJitter
    }
}

/// Subset of `GitHubClient` used by `PollingService` (tests inject fakes).
public protocol GitHubPollingClient: Sendable {
    func fetchNotifications() async throws -> FetchResult<[NotificationThread]>
    func fetchRepo(owner: String, name: String) async throws -> FetchResult<GitHubRepository>
    func fetchPulls(owner: String, name: String) async throws -> FetchResult<[PullRequestSummary]>
    func fetchIssues(owner: String, name: String) async throws -> FetchResult<[IssueSummary]>
}

extension GitHubClient: GitHubPollingClient {}

/// Orchestrates scheduled and manual polling (PLAN.md: T2.3).
///
/// - Scheduled ticks: 10 min base + 0–30 s jitter, then notifications (when
///   allowed) and all monitored repos.
/// - Notifications honor `X-Poll-Interval`; manual refresh always re-fetches
///   repos but skips notifications until the interval elapses.
/// - Repo polls run with at most four concurrent fetches; `stop()` cancels all.
public final class PollingService: @unchecked Sendable {

    public typealias JitterProvider = @Sendable () -> TimeInterval

    private let client: GitHubPollingClient
    private let diffEngine: DiffEngine
    private let clock: Clock
    private let jitter: JitterProvider
    private let onItems: @Sendable ([InboxItem]) -> Void

    private let stateLock = NSLock()
    private var loopTask: Task<Void, Never>?
    private var nextNotificationPollAt: Date?
    private var monitoredRepos: [MonitoredRepo] = []
    private var selfLogin: String?
    private var reasonFilter = ReasonFilter()
    private var noiseFilter = NoiseFilter()

    public private(set) var isRunning = false

    public init(
        client: GitHubPollingClient,
        cache: CacheStore,
        clock: Clock = SystemClock(),
        jitter: @escaping JitterProvider = { PollingSchedule.sampleJitter() },
        onItems: @escaping @Sendable ([InboxItem]) -> Void
    ) {
        self.client = client
        self.diffEngine = DiffEngine(cache: cache)
        self.clock = clock
        self.jitter = jitter
        self.onItems = onItems
    }

    /// Whether a manual refresh may fetch notifications (for UI tooltip).
    public var canRefreshNotifications: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let next = nextNotificationPollAt else { return true }
        return clock.now >= next
    }

    public func start(monitoredRepos: [MonitoredRepo], selfLogin: String?) {
        stateLock.lock()
        self.monitoredRepos = monitoredRepos
        self.selfLogin = selfLogin
        noiseFilter.selfLogin = selfLogin
        isRunning = true
        stateLock.unlock()

        loopTask?.cancel()
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    public func stop() {
        loopTask?.cancel()
        loopTask = nil
        stateLock.lock()
        isRunning = false
        stateLock.unlock()
    }

    /// Manual refresh: repo polls always; notifications only when interval allows.
    public func refreshNow() async {
        await poll(includeNotifications: canRefreshNotifications)
    }

    /// Runs one scheduled tick (notifications + repos). Exposed for tests.
    func runScheduledTickForTests() async {
        await poll(includeNotifications: true)
    }

    /// Polls repos only — exposed for concurrency tests.
    func pollReposForTests(_ repos: [MonitoredRepo]) async {
        stateLock.lock()
        monitoredRepos = repos
        stateLock.unlock()
        await pollRepos()
    }

    // MARK: - Loop

    private func runLoop() async {
        await poll(includeNotifications: true)

        while !Task.isCancelled {
            let target = clock.now.addingTimeInterval(PollingSchedule.baseInterval + jitter())
            do {
                try await clock.sleep(until: target)
            } catch {
                break
            }
            guard !Task.isCancelled else { break }
            await poll(includeNotifications: canRefreshNotifications)
        }

        stateLock.lock()
        isRunning = false
        stateLock.unlock()
    }

    private func poll(includeNotifications: Bool) async {
        if includeNotifications {
            await pollNotifications()
        }
        await pollRepos()
    }

    // MARK: - Notifications

    private func pollNotifications() async {
        guard notificationsAllowed else { return }

        do {
            let result = try await client.fetchNotifications()
            let pollInterval: TimeInterval?
            let threads: [NotificationThread]

            switch result {
            case .fresh(let body, _, let interval):
                threads = body
                pollInterval = interval
            case .notModified(let interval):
                threads = []
                pollInterval = interval
            }

            recordNotificationPollInterval(pollInterval)

            let items = threads.map(Self.inboxItem(from:))
            let diffed = diffEngine.diffThreads(items)
            let filtered = reasonFilter.filter(diffed)
            if !filtered.isEmpty {
                onItems(filtered)
            }
        } catch {
            if Task.isCancelled { return }
        }
    }

    private var notificationsAllowed: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let next = nextNotificationPollAt else { return true }
        return clock.now >= next
    }

    private func recordNotificationPollInterval(_ interval: TimeInterval?) {
        let delay = interval ?? PollingSchedule.baseInterval
        stateLock.lock()
        nextNotificationPollAt = clock.now.addingTimeInterval(delay)
        stateLock.unlock()
    }

    // MARK: - Repos

    private func pollRepos() async {
        stateLock.lock()
        let repos = monitoredRepos
        let filter = noiseFilter
        stateLock.unlock()

        guard !repos.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            var index = 0

            func addNext() {
                guard index < repos.count else { return }
                let repo = repos[index]
                index += 1
                group.addTask { [weak self] in
                    await self?.pollRepo(repo, noiseFilter: filter)
                }
            }

            for _ in 0..<min(PollingSchedule.maxConcurrentRepoPolls, repos.count) {
                addNext()
            }

            while await group.next() != nil {
                addNext()
            }
        }
    }

    private func pollRepo(_ repo: MonitoredRepo, noiseFilter: NoiseFilter) async {
        do {
            try Task.checkCancellation()

            let metaResult = try await client.fetchRepo(owner: repo.owner, name: repo.name)
            if case .fresh(let repository, _, _) = metaResult {
                if let starItem = diffEngine.diffStarCount(
                    repository.stargazersCount,
                    forRepo: repo,
                    now: clock.now
                ) {
                    onItems([starItem])
                }
            }

            try Task.checkCancellation()

            let pullsResult = try await client.fetchPulls(owner: repo.owner, name: repo.name)
            let pullItems: [InboxItem]
            if case .fresh(let pulls, _, _) = pullsResult {
                pullItems = pulls.compactMap { pr in
                    guard noiseFilter.shouldInclude(
                        authorLogin: pr.authorLogin,
                        authorType: pr.authorType,
                        isDraft: pr.draft
                    ) else { return nil }
                    return Self.inboxItem(from: pr, repo: repo, now: clock.now)
                }
            } else {
                pullItems = []
            }

            try Task.checkCancellation()

            let issuesResult = try await client.fetchIssues(owner: repo.owner, name: repo.name)
            let issueItems: [InboxItem]
            if case .fresh(let issues, _, _) = issuesResult {
                issueItems = issues.compactMap { issue in
                    guard noiseFilter.shouldInclude(
                        authorLogin: issue.authorLogin,
                        authorType: issue.authorType,
                        isDraft: false
                    ) else { return nil }
                    return Self.inboxItem(from: issue, repo: repo, now: clock.now)
                }
            } else {
                issueItems = []
            }

            let repoItems = pullItems + issueItems
            let diffed = diffEngine.diffRepoItems(repoItems, forRepo: repo)
            if !diffed.isEmpty {
                onItems(diffed)
            }
        } catch {
            if Task.isCancelled { return }
        }
    }

    // MARK: - Mapping

    private static func inboxItem(from thread: NotificationThread) -> InboxItem {
        InboxItem(
            id: thread.id,
            title: thread.subject.title,
            repoFullName: thread.repository.fullName,
            url: URL(string: thread.subject.url),
            source: .thread(reason: thread.reason),
            updatedAt: thread.updatedAt
        )
    }

    private static func inboxItem(from pr: PullRequestSummary, repo: MonitoredRepo, now: Date) -> InboxItem {
        InboxItem(
            id: "pr:\(repo.fullName):\(pr.id)",
            title: pr.title,
            repoFullName: repo.fullName,
            url: pr.htmlURL,
            source: .synthetic(.newOnMyRepos),
            updatedAt: now
        )
    }

    private static func inboxItem(from issue: IssueSummary, repo: MonitoredRepo, now: Date) -> InboxItem {
        InboxItem(
            id: "issue:\(repo.fullName):\(issue.id)",
            title: issue.title,
            repoFullName: repo.fullName,
            url: issue.htmlURL,
            source: .synthetic(.newOnMyRepos),
            updatedAt: now
        )
    }
}
