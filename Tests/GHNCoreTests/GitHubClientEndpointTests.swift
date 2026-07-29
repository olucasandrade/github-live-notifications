import XCTest
@testable import GHNCore

final class GitHubClientEndpointTests: XCTestCase {

    override func tearDown() {
        StubURLProtocol.requestHandler = nil
        StubURLProtocol.observedRequests = []
        super.tearDown()
    }

    // MARK: - GET /user

    func testFetchUserDecodesLogin() async throws {
        let (client, _) = makeClient { request in
            XCTAssertEqual(request.url?.path, "/user")
            return (
                Self.httpResponse(url: request.url!, status: 200, headers: ["ETag": "W/\"user\""]),
                Data(#"{"login":"octocat","id":1}"#.utf8)
            )
        }

        let result = try await client.fetchUser()

        guard case .fresh(let user, _, _) = result else {
            return XCTFail("expected .fresh, got \(result)")
        }
        XCTAssertEqual(user.login, "octocat")
        XCTAssertEqual(user.id, 1)
    }

    // MARK: - GET /notifications (≤2 pages)

    func testFetchNotificationsUsesAllFalseAndPerPage50() async throws {
        let (client, _) = makeClient { request in
            XCTAssertEqual(request.url?.path, "/notifications")
            XCTAssertEqual(request.url?.query, "all=false&per_page=50")
            return (
                Self.httpResponse(url: request.url!, status: 200),
                Data("[]".utf8)
            )
        }

        _ = try await client.fetchNotifications()
    }

    func testFetchNotificationsFollowsNextLinkUpToTwoPages() async throws {
        var callCount = 0
        let (client, _) = makeClient { request in
            callCount += 1
            if callCount == 1 {
                XCTAssertEqual(request.url?.path, "/notifications")
                let link = "<https://api.github.com/notifications?all=false&page=2&per_page=50>; rel=\"next\""
                return (
                    Self.httpResponse(url: request.url!, status: 200, headers: ["Link": link]),
                    Self.notificationsJSON(ids: (1...50).map(String.init))
                )
            }
            XCTAssertEqual(request.url?.absoluteString,
                           "https://api.github.com/notifications?all=false&page=2&per_page=50")
            let link = "<https://api.github.com/notifications?all=false&page=3&per_page=50>; rel=\"next\""
            return (
                Self.httpResponse(url: request.url!, status: 200, headers: ["Link": link]),
                Self.notificationsJSON(ids: ["51", "52"])
            )
        }

        let result = try await client.fetchNotifications()

        guard case .fresh(let threads, _, _) = result else {
            return XCTFail("expected .fresh, got \(result)")
        }
        XCTAssertEqual(threads.count, 52)
        XCTAssertEqual(callCount, 2)
    }

    func testFetchNotifications304OnFirstPageSkipsSecondPage() async throws {
        let (client, _) = makeClient { request in
            (
                Self.httpResponse(url: request.url!, status: 200, headers: ["ETag": "W/\"n1\""]),
                Self.notificationsJSON(ids: ["1"])
            )
        }
        _ = try await client.fetchNotifications()

        StubURLProtocol.requestHandler = { request in
            (Self.httpResponse(url: request.url!, status: 304), Data())
        }
        let result = try await client.fetchNotifications()

        guard case .notModified = result else {
            return XCTFail("expected .notModified, got \(result)")
        }
        XCTAssertEqual(StubURLProtocol.observedRequests.count, 2)
    }

    // MARK: - GET /user/repos

    func testFetchUserReposDecodesRepoList() async throws {
        let (client, _) = makeClient { request in
            XCTAssertEqual(request.url?.path, "/user/repos")
            return (
                Self.httpResponse(url: request.url!, status: 200),
                Data("""
                [
                  {
                    "id": 1,
                    "name": "Hello-World",
                    "full_name": "octocat/Hello-World",
                    "owner": {"login": "octocat"},
                    "fork": false,
                    "archived": false,
                    "private": false,
                    "stargazers_count": 80
                  }
                ]
                """.utf8)
            )
        }

        let result = try await client.fetchUserRepos()

        guard case .fresh(let repos, _, _) = result else {
            return XCTFail("expected .fresh, got \(result)")
        }
        XCTAssertEqual(repos.count, 1)
        XCTAssertEqual(repos[0].fullName, "octocat/Hello-World")
        XCTAssertEqual(repos[0].ownerLogin, "octocat")
        XCTAssertFalse(repos[0].fork)
        XCTAssertFalse(repos[0].archived)
        XCTAssertEqual(repos[0].stargazersCount, 80)
    }

    // MARK: - GET /repos/{owner}/{repo}

    func testFetchRepoDecodesMetadata() async throws {
        let (client, _) = makeClient { request in
            XCTAssertEqual(request.url?.path, "/repos/octocat/Hello-World")
            return (
                Self.httpResponse(url: request.url!, status: 200),
                Data("""
                {
                  "id": 1,
                  "name": "Hello-World",
                  "full_name": "octocat/Hello-World",
                  "owner": {"login": "octocat"},
                  "fork": false,
                  "archived": false,
                  "private": false,
                  "stargazers_count": 80
                }
                """.utf8)
            )
        }

        let result = try await client.fetchRepo(owner: "octocat", name: "Hello-World")

        guard case .fresh(let repo, _, _) = result else {
            return XCTFail("expected .fresh, got \(result)")
        }
        XCTAssertEqual(repo.fullName, "octocat/Hello-World")
        XCTAssertEqual(repo.stargazersCount, 80)
    }

    // MARK: - GET /repos/{owner}/{repo}/pulls

    func testFetchPullsRequestsOpenState() async throws {
        let (client, _) = makeClient { request in
            XCTAssertEqual(request.url?.path, "/repos/octocat/Hello-World/pulls")
            XCTAssertTrue(request.url?.query?.contains("state=open") == true)
            return (
                Self.httpResponse(url: request.url!, status: 200),
                Data("""
                [
                  {
                    "id": 1,
                    "number": 42,
                    "title": "Fix bug",
                    "html_url": "https://github.com/octocat/Hello-World/pull/42",
                    "user": {"login": "dev", "type": "User"},
                    "draft": false
                  }
                ]
                """.utf8)
            )
        }

        let result = try await client.fetchPulls(owner: "octocat", name: "Hello-World")

        guard case .fresh(let pulls, _, _) = result else {
            return XCTFail("expected .fresh, got \(result)")
        }
        XCTAssertEqual(pulls.count, 1)
        XCTAssertEqual(pulls[0].number, 42)
        XCTAssertEqual(pulls[0].title, "Fix bug")
        XCTAssertEqual(pulls[0].authorLogin, "dev")
        XCTAssertFalse(pulls[0].draft)
    }

    // MARK: - GET /repos/{owner}/{repo}/issues

    func testFetchIssuesSkipsPullRequestDupes() async throws {
        let (client, _) = makeClient { request in
            XCTAssertEqual(request.url?.path, "/repos/octocat/Hello-World/issues")
            XCTAssertTrue(request.url?.query?.contains("state=open") == true)
            return (
                Self.httpResponse(url: request.url!, status: 200),
                Data("""
                [
                  {
                    "id": 1,
                    "number": 1,
                    "title": "Real issue",
                    "html_url": "https://github.com/octocat/Hello-World/issues/1",
                    "user": {"login": "dev", "type": "User"}
                  },
                  {
                    "id": 2,
                    "number": 2,
                    "title": "PR disguised as issue",
                    "html_url": "https://github.com/octocat/Hello-World/pull/2",
                    "pull_request": {"url": "https://api.github.com/repos/octocat/Hello-World/pulls/2"},
                    "user": {"login": "dev", "type": "User"}
                  },
                  {
                    "id": 3,
                    "number": 3,
                    "title": "Another issue",
                    "html_url": "https://github.com/octocat/Hello-World/issues/3",
                    "user": {"login": "dev", "type": "User"}
                  }
                ]
                """.utf8)
            )
        }

        let result = try await client.fetchIssues(owner: "octocat", name: "Hello-World")

        guard case .fresh(let issues, _, _) = result else {
            return XCTFail("expected .fresh, got \(result)")
        }
        XCTAssertEqual(issues.map(\.number), [1, 3])
        XCTAssertEqual(issues.map(\.title), ["Real issue", "Another issue"])
    }

    // MARK: - PATCH /notifications/threads/{id}

    func testMarkThreadReadSendsPATCHAndAccepts205() async throws {
        let (client, _) = makeClient { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/notifications/threads/abc123")
            return (Self.httpResponse(url: request.url!, status: 205), Data())
        }

        try await client.markThreadRead(threadID: "abc123")
    }

    func testMarkThreadReadMaps401ToInvalidToken() async {
        let (client, _) = makeClient { request in
            (Self.httpResponse(url: request.url!, status: 401), Data())
        }

        do {
            try await client.markThreadRead(threadID: "x")
            XCTFail("expected throw")
        } catch let error as GitHubClientError {
            XCTAssertEqual(error, .invalidToken)
        } catch {
            XCTFail("expected GitHubClientError.invalidToken, got \(error)")
        }
    }

    // MARK: - PUT /notifications (mark all read)

    func testMarkAllNotificationsReadSendsPUT() async throws {
        let (client, _) = makeClient { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.url?.path, "/notifications")
            return (Self.httpResponse(url: request.url!, status: 205), Data())
        }

        try await client.markAllNotificationsRead()
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

    private static func notificationsJSON(ids: [String]) -> Data {
        let items = ids.map { id in
            """
            {
              "id": "\(id)",
              "reason": "mention",
              "subject": {"title": "Thread \(id)", "url": "https://api.github.com/x", "type": "Issue"},
              "repository": {"full_name": "octocat/Hello-World"},
              "updated_at": "2024-01-01T00:00:00Z"
            }
            """
        }.joined(separator: ",")
        return Data("[\(items)]".utf8)
    }
}
