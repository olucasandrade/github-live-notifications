import XCTest
@testable import GHNCore

final class InboxActionsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var cache: UserDefaultsCacheStore!
    private var client: GitHubClient!
    private var actions: InboxActions!

    private let repo = MonitoredRepo(owner: "octocat", name: "hello")
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "InboxActionsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        cache = UserDefaultsCacheStore(defaults: defaults)
        StubURLProtocol.observedRequests = []
        StubURLProtocol.requestHandler = { request in
            (
                Self.httpResponse(url: request.url!, status: 205),
                Data()
            )
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        client = GitHubClient(session: URLSession(configuration: config))
        actions = InboxActions(client: client, cache: cache)
    }

    override func tearDown() {
        StubURLProtocol.requestHandler = nil
        StubURLProtocol.observedRequests = []
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    private func thread(id: String) -> InboxItem {
        InboxItem(
            id: id,
            title: "Thread \(id)",
            repoFullName: repo.fullName,
            url: URL(string: "https://github.com/\(repo.fullName)/issues/1"),
            source: .thread(reason: .mention),
            updatedAt: now
        )
    }

    private func synthetic(id: String, source: InboxItem.SyntheticSource) -> InboxItem {
        InboxItem(
            id: id,
            title: "Synthetic \(id)",
            repoFullName: repo.fullName,
            url: nil,
            source: .synthetic(source),
            updatedAt: now
        )
    }

    private static func httpResponse(
        url: URL, status: Int, headers: [String: String] = [:]
    ) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!
    }

    // MARK: - Thread mark-read (PATCH)

    func testMarkThreadReadSendsPATCHToNotificationsThreads() async throws {
        let item = thread(id: "thread-42")

        try await actions.markThreadRead(item)

        XCTAssertEqual(StubURLProtocol.observedRequests.count, 1)
        let request = try XCTUnwrap(StubURLProtocol.observedRequests.first)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.path, "/notifications/threads/thread-42")
    }

    func testMarkThreadReadRecordsLocalReadState() async throws {
        let item = thread(id: "t1")

        XCTAssertTrue(actions.isUnread(item))
        try await actions.markThreadRead(item)
        XCTAssertFalse(actions.isUnread(item))
    }

    func testMarkReadRoutesThreadToAPI() async throws {
        let item = thread(id: "t9")

        try await actions.markRead(item)

        XCTAssertEqual(StubURLProtocol.observedRequests.count, 1)
        XCTAssertEqual(StubURLProtocol.observedRequests.first?.httpMethod, "PATCH")
        XCTAssertFalse(actions.isUnread(item))
    }

    // MARK: - Synthetic dismiss (local)

    func testDismissSyntheticDoesNotCallAPI() async throws {
        let stars = synthetic(id: "stars:octocat/hello:100", source: .stars)
        let newRepo = synthetic(id: "pr:42", source: .newOnMyRepos)

        actions.dismissSynthetic(stars)
        actions.dismissSynthetic(newRepo)

        XCTAssertEqual(StubURLProtocol.observedRequests.count, 0)
        XCTAssertFalse(actions.isUnread(stars))
        XCTAssertFalse(actions.isUnread(newRepo))
    }

    func testMarkReadRoutesSyntheticToLocalDismiss() async throws {
        let item = synthetic(id: "stars:octocat/hello:50", source: .stars)

        try await actions.markRead(item)

        XCTAssertEqual(StubURLProtocol.observedRequests.count, 0)
        XCTAssertFalse(actions.isUnread(item))
    }

    // MARK: - Mark all

    func testMarkAllReadCallsPUTNotificationsAndDismissesSynthetics() async throws {
        StubURLProtocol.requestHandler = { request in
            if request.httpMethod == "PUT" {
                XCTAssertEqual(request.url?.path, "/notifications")
            }
            return (Self.httpResponse(url: request.url!, status: 205), Data())
        }

        let items = [
            thread(id: "t1"),
            thread(id: "t2"),
            synthetic(id: "stars:octocat/hello:10", source: .stars),
            synthetic(id: "pr:7", source: .newOnMyRepos),
        ]

        try await actions.markAllRead(in: items)

        XCTAssertEqual(StubURLProtocol.observedRequests.count, 1)
        XCTAssertEqual(StubURLProtocol.observedRequests.first?.httpMethod, "PUT")
        XCTAssertEqual(StubURLProtocol.observedRequests.first?.url?.path, "/notifications")
        XCTAssertTrue(items.allSatisfy { !actions.isUnread($0) })
    }

    func testMarkAllReadWithOnlySyntheticsSkipsAPI() async throws {
        let items = [
            synthetic(id: "stars:1", source: .stars),
            synthetic(id: "pr:2", source: .newOnMyRepos),
        ]

        try await actions.markAllRead(in: items)

        XCTAssertEqual(StubURLProtocol.observedRequests.count, 0)
        XCTAssertTrue(items.allSatisfy { !actions.isUnread($0) })
    }

    func testUnreadItemsFiltersReadThreadsAndDismissedSynthetics() async throws {
        let items = [
            thread(id: "t1"),
            thread(id: "t2"),
            synthetic(id: "s1", source: .stars),
        ]

        try await actions.markThreadRead(items[0])
        actions.dismissSynthetic(items[2])

        let unread = actions.unreadItems(in: items)
        XCTAssertEqual(unread.map(\.id), ["t2"])
    }

    func testWipeAllClearsReadAndDismissedState() async throws {
        let items = [thread(id: "t1"), synthetic(id: "s1", source: .stars)]
        try await actions.markAllRead(in: items)
        XCTAssertTrue(items.allSatisfy { !actions.isUnread($0) })

        cache.wipeAll()

        XCTAssertTrue(actions.isUnread(items[0]))
        XCTAssertTrue(actions.isUnread(items[1]))
    }
}
