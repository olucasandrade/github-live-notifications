import XCTest
@testable import GHNCore

final class ThreadHTMLURLResolverTests: XCTestCase {

    override func tearDown() {
        StubURLProtocol.requestHandler = nil
        StubURLProtocol.observedRequests = []
        super.tearDown()
    }

    func testResolveFetchesSubjectURLAndReturnsHTMLURL() async throws {
        let thread = Self.makeThread(
            id: "thread-1",
            subjectURL: "https://api.github.com/repos/octocat/Hello-World/issues/42"
        )
        let (client, _) = makeClient { request in
            XCTAssertEqual(request.url?.path, "/repos/octocat/Hello-World/issues/42")
            return (
                Self.httpResponse(url: request.url!, status: 200),
                Data(#"{"html_url":"https://github.com/octocat/Hello-World/issues/42"}"#.utf8)
            )
        }

        let resolver = ThreadHTMLURLResolver(client: client)
        let url = await resolver.resolve(thread: thread)

        XCTAssertEqual(url, URL(string: "https://github.com/octocat/Hello-World/issues/42"))
    }

    func testResolveCachesByThreadID() async throws {
        var fetchCount = 0
        let thread = Self.makeThread(
            id: "thread-cache",
            subjectURL: "https://api.github.com/repos/octocat/Hello-World/issues/1"
        )
        let (client, _) = makeClient { request in
            fetchCount += 1
            return (
                Self.httpResponse(url: request.url!, status: 200),
                Data(#"{"html_url":"https://github.com/octocat/Hello-World/issues/1"}"#.utf8)
            )
        }

        let resolver = ThreadHTMLURLResolver(client: client)
        _ = await resolver.resolve(thread: thread)
        _ = await resolver.resolve(thread: thread)

        XCTAssertEqual(fetchCount, 1)
    }

    func testResolveFallbackWhenFetchFails() async throws {
        let thread = Self.makeThread(
            id: "thread-fallback",
            subjectURL: "https://api.github.com/repos/octocat/Hello-World/issues/42"
        )
        let (client, _) = makeClient { request in
            (Self.httpResponse(url: request.url!, status: 404), Data())
        }

        let resolver = ThreadHTMLURLResolver(client: client)
        let url = await resolver.resolve(thread: thread)

        XCTAssertEqual(url, URL(string: "https://github.com/octocat/Hello-World/issues/42"))
    }

    func testResolveFallbackPullRequestPath() async throws {
        let thread = Self.makeThread(
            id: "thread-pr",
            subjectURL: "https://api.github.com/repos/octocat/Hello-World/pulls/7"
        )
        let (client, _) = makeClient { request in
            (Self.httpResponse(url: request.url!, status: 500), Data())
        }

        let resolver = ThreadHTMLURLResolver(client: client)
        let url = await resolver.resolve(thread: thread)

        XCTAssertEqual(url, URL(string: "https://github.com/octocat/Hello-World/pull/7"))
    }

    func testResolveFallbackCommitPath() async throws {
        let thread = Self.makeThread(
            id: "thread-commit",
            subjectURL: "https://api.github.com/repos/octocat/Hello-World/commits/deadbeef"
        )
        let (client, _) = makeClient { request in
            (Self.httpResponse(url: request.url!, status: 403), Data())
        }

        let resolver = ThreadHTMLURLResolver(client: client)
        let url = await resolver.resolve(thread: thread)

        XCTAssertEqual(url, URL(string: "https://github.com/octocat/Hello-World/commit/deadbeef"))
    }

    func testResolveCachesFallbackResultWithoutRefetching() async throws {
        var fetchCount = 0
        let thread = Self.makeThread(
            id: "thread-fallback-cache",
            subjectURL: "https://api.github.com/repos/octocat/Hello-World/issues/5"
        )
        let (client, _) = makeClient { request in
            fetchCount += 1
            return (Self.httpResponse(url: request.url!, status: 404), Data())
        }

        let resolver = ThreadHTMLURLResolver(client: client)
        _ = await resolver.resolve(thread: thread)
        _ = await resolver.resolve(thread: thread)

        XCTAssertEqual(fetchCount, 1)
    }

    func testResolveReturnsExistingGitHubWebURLWithoutFetching() async throws {
        var fetchCount = 0
        let thread = Self.makeThread(
            id: "thread-web",
            subjectURL: "https://github.com/octocat/Hello-World/issues/99"
        )
        let (client, _) = makeClient { _ in
            fetchCount += 1
            fatalError("should not fetch")
        }

        let resolver = ThreadHTMLURLResolver(client: client)
        let url = await resolver.resolve(thread: thread)

        XCTAssertEqual(url, URL(string: "https://github.com/octocat/Hello-World/issues/99"))
        XCTAssertEqual(fetchCount, 0)
    }

    // MARK: - Helpers

    private func makeClient(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> (GitHubClient, URLSession) {
        StubURLProtocol.requestHandler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        return (GitHubClient(session: session), session)
    }

    private static func httpResponse(
        url: URL, status: Int, headers: [String: String] = [:]
    ) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!
    }

    private static func makeThread(id: String, subjectURL: String) -> NotificationThread {
        NotificationThread(
            id: id,
            reason: .mention,
            subject: .init(title: "Test", url: subjectURL, type: "Issue"),
            repository: .init(fullName: "octocat/Hello-World"),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
