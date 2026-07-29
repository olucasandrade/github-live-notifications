import XCTest
@testable import GHNCore

final class GitHubClientTests: XCTestCase {

    struct TestPayload: Decodable, Equatable {
        let login: String
    }

    override func tearDown() {
        StubURLProtocol.requestHandler = nil
        StubURLProtocol.observedRequests = []
        super.tearDown()
    }

    // MARK: - Authorization

    func testGetSendsBearerTokenWhenConfigured() async throws {
        let (client, _) = makeClient { request in
            (
                Self.httpResponse(url: request.url!, status: 200),
                Data(#"{"login":"octocat"}"#.utf8)
            )
        }
        client.token = "ghp_test_token"

        _ = try await client.get("/user", as: TestPayload.self)

        XCTAssertEqual(
            StubURLProtocol.observedRequests.last?.value(forHTTPHeaderField: "Authorization"),
            "Bearer ghp_test_token"
        )
    }

    // MARK: - Success path

    func testGetDecodesBodyAndExposesETagAndPollInterval() async throws {
        let (client, _) = makeClient { request in
            (
                Self.httpResponse(url: request.url!, status: 200, headers: [
                    "ETag": "W/\"abc123\"",
                    "X-Poll-Interval": "60",
                ]),
                Data(#"{"login":"octocat"}"#.utf8)
            )
        }

        let result = try await client.get("/user", as: TestPayload.self)

        guard case .fresh(let body, let etag, let pollInterval) = result else {
            return XCTFail("expected .fresh, got \(result)")
        }
        XCTAssertEqual(body, TestPayload(login: "octocat"))
        XCTAssertEqual(etag, "W/\"abc123\"")
        XCTAssertEqual(pollInterval, 60)
    }

    func testMissingPollIntervalHeaderYieldsNil() async throws {
        let (client, _) = makeClient { request in
            (Self.httpResponse(url: request.url!, status: 200), Data(#"{"login":"octocat"}"#.utf8))
        }

        let result = try await client.get("/user", as: TestPayload.self)

        guard case .fresh(_, let etag, let pollInterval) = result else {
            return XCTFail("expected .fresh, got \(result)")
        }
        XCTAssertNil(etag)
        XCTAssertNil(pollInterval)
    }

    // MARK: - ETag / 304

    func testStoredETagIsSentAsIfNoneMatchOnNextRequest() async throws {
        let (client, _) = makeClient { request in
            (
                Self.httpResponse(url: request.url!, status: 200, headers: ["ETag": "W/\"abc123\""]),
                Data(#"{"login":"octocat"}"#.utf8)
            )
        }
        _ = try await client.get("/user", as: TestPayload.self)

        StubURLProtocol.requestHandler = { request in
            (Self.httpResponse(url: request.url!, status: 304), Data())
        }
        _ = try await client.get("/user", as: TestPayload.self)

        XCTAssertEqual(StubURLProtocol.observedRequests.count, 2)
        XCTAssertEqual(StubURLProtocol.observedRequests[0].value(forHTTPHeaderField: "If-None-Match"), nil)
        XCTAssertEqual(StubURLProtocol.observedRequests[1].value(forHTTPHeaderField: "If-None-Match"), "W/\"abc123\"")
    }

    func testNotModifiedSkipsDecodingAndCarriesPollInterval() async throws {
        // Seed the ETag with a 200, then answer 304 with a body that would
        // fail decoding — a .notModified result proves no decode happened.
        let (client, _) = makeClient { request in
            (
                Self.httpResponse(url: request.url!, status: 200, headers: ["ETag": "W/\"abc123\""]),
                Data(#"{"login":"octocat"}"#.utf8)
            )
        }
        _ = try await client.get("/user", as: TestPayload.self)

        StubURLProtocol.requestHandler = { request in
            (
                Self.httpResponse(url: request.url!, status: 304, headers: ["X-Poll-Interval": "90"]),
                Data("this is not json".utf8)
            )
        }
        let result = try await client.get("/user", as: TestPayload.self)

        guard case .notModified(let pollInterval) = result else {
            return XCTFail("expected .notModified, got \(result)")
        }
        XCTAssertEqual(pollInterval, 90)
    }

    func testETagIsKeyedPerURL() async throws {
        let (client, _) = makeClient { request in
            (
                Self.httpResponse(url: request.url!, status: 200, headers: ["ETag": "W/\"abc123\""]),
                Data(#"{"login":"octocat"}"#.utf8)
            )
        }
        _ = try await client.get("/user", as: TestPayload.self)

        StubURLProtocol.requestHandler = { request in
            (Self.httpResponse(url: request.url!, status: 304), Data())
        }
        _ = try await client.get("/notifications", as: TestPayload.self)

        XCTAssertEqual(StubURLProtocol.observedRequests.last?.value(forHTTPHeaderField: "If-None-Match"), nil)
    }

    // MARK: - Errors

    func test401MapsToInvalidToken() async {
        let (client, _) = makeClient { request in
            (Self.httpResponse(url: request.url!, status: 401), Data())
        }

        do {
            _ = try await client.get("/user", as: TestPayload.self)
            XCTFail("expected throw")
        } catch let error as GitHubClientError {
            XCTAssertEqual(error, .invalidToken)
        } catch {
            XCTFail("expected GitHubClientError.invalidToken, got \(error)")
        }
    }

    func test403WithoutRateLimitExhaustionMapsToInvalidToken() async {
        let (client, _) = makeClient { request in
            (Self.httpResponse(url: request.url!, status: 403), Data())
        }

        do {
            _ = try await client.get("/user", as: TestPayload.self)
            XCTFail("expected throw")
        } catch let error as GitHubClientError {
            XCTAssertEqual(error, .invalidToken)
        } catch {
            XCTFail("expected GitHubClientError.invalidToken, got \(error)")
        }
    }

    func test403WithRateLimitRemainingZeroMapsToRateLimited() async {
        let resetEpoch: TimeInterval = 1_700_000_000
        let (client, _) = makeClient { request in
            (
                Self.httpResponse(url: request.url!, status: 403, headers: [
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": "1700000000",
                ]),
                Data()
            )
        }

        do {
            _ = try await client.get("/user", as: TestPayload.self)
            XCTFail("expected throw")
        } catch let error as GitHubClientError {
            XCTAssertEqual(error, .rateLimited(reset: Date(timeIntervalSince1970: resetEpoch)))
        } catch {
            XCTFail("expected GitHubClientError.rateLimited, got \(error)")
        }
    }

    func testHTTPErrorStatusThrows() async {
        let (client, _) = makeClient { request in
            (Self.httpResponse(url: request.url!, status: 500), Data())
        }

        do {
            _ = try await client.get("/user", as: TestPayload.self)
            XCTFail("expected throw")
        } catch let error as GitHubClientError {
            XCTAssertEqual(error, .httpStatus(500))
        } catch {
            XCTFail("expected GitHubClientError, got \(error)")
        }
    }

    func testMalformedJSONOn200ThrowsDecodingError() async {
        let (client, _) = makeClient { request in
            (Self.httpResponse(url: request.url!, status: 200), Data("not json".utf8))
        }

        do {
            _ = try await client.get("/user", as: TestPayload.self)
            XCTFail("expected throw")
        } catch is DecodingError {
            // expected
        } catch {
            XCTFail("expected DecodingError, got \(error)")
        }
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
}

/// `URLProtocol` stub fixture: every request is answered by a test-provided handler.
final class StubURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var observedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.requestHandler else {
            fatalError("StubURLProtocol.requestHandler not set")
        }
        StubURLProtocol.observedRequests.append(request)
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !data.isEmpty {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
