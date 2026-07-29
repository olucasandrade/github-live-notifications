import Foundation

public enum GitHubClientError: Error, Equatable {
    case invalidURL(String)
    case unexpectedResponse
    case httpStatus(Int)
    case invalidToken
    case rateLimited(reset: Date)
}

/// Outcome of a conditional GET (PLAN.md: ETag; honor X-Poll-Interval).
public enum FetchResult<T> {
    /// 2xx with a decoded body. Carries the response ETag (already stored by
    /// the client) and the parsed `X-Poll-Interval` in seconds, if present.
    case fresh(body: T, etag: String?, pollInterval: TimeInterval?)
    /// 304 — body was not decoded and nothing changed. A 304 does not count
    /// against the primary rate limit, so there is no rate-cost handling here.
    case notModified(pollInterval: TimeInterval?)
}

/// Minimal GitHub REST client: generic conditional GET with in-memory ETag
/// revalidation. Concrete endpoints are added on top of `get(_:as:)`.
public final class GitHubClient: @unchecked Sendable {

    public let baseURL: URL

    private let session: URLSession
    private let lock = NSLock()
    private var etags: [URL: String] = [:]
    private var _token: String?

    /// Classic PAT sent as `Authorization: Bearer` on every request when set.
    public var token: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _token
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _token = newValue
        }
    }

    public init(
        baseURL: URL = URL(string: "https://api.github.com")!,
        session: URLSession = .shared,
        token: String? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self._token = token
    }

    /// GET `baseURL + path`, revalidating with a stored ETag when one exists.
    public func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> FetchResult<T> {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw GitHubClientError.invalidURL(path)
        }

        let (data, http) = try await performAuthenticatedGet(url: url)

        let pollInterval = http.value(forHTTPHeaderField: "X-Poll-Interval").flatMap(TimeInterval.init)

        switch http.statusCode {
        case 304:
            return .notModified(pollInterval: pollInterval)
        case 200...299:
            let body = try Self.jsonDecoder.decode(T.self, from: data)
            let etag = http.value(forHTTPHeaderField: "ETag")
            if let etag {
                storeETag(etag, for: url)
            }
            return .fresh(body: body, etag: etag, pollInterval: pollInterval)
        default:
            throw mapHTTPError(status: http.statusCode, response: http)
        }
    }

    func mapHTTPError(status: Int, response: HTTPURLResponse) -> GitHubClientError {
        switch status {
        case 401:
            return .invalidToken
        case 403:
            if response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0",
               let resetHeader = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
               let resetEpoch = TimeInterval(resetHeader) {
                return .rateLimited(reset: Date(timeIntervalSince1970: resetEpoch))
            }
            return .invalidToken
        default:
            return .httpStatus(status)
        }
    }

    // MARK: - ETag store (in-memory; persistence lands with the cache store)

    func storedETag(for url: URL) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return etags[url]
    }

    func storeETag(_ etag: String, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        etags[url] = etag
    }

    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Raw GET for pagination helpers; reuses ETag revalidation keyed by request URL.
    func performGet(_ path: String) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw GitHubClientError.invalidURL(path)
        }
        return try await performGetURL(url)
    }

    func performGetURL(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        try await performAuthenticatedGet(url: url)
    }

    private func performAuthenticatedGet(url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let etag = storedETag(for: url) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubClientError.unexpectedResponse
        }
        return (data, http)
    }

    static func nextPageURL(from linkHeader: String?) -> URL? {
        guard let linkHeader else { return nil }
        for part in linkHeader.split(separator: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("rel=\"next\"") else { continue }
            guard let start = trimmed.firstIndex(of: "<"),
                  let end = trimmed.firstIndex(of: ">"),
                  start < end else { continue }
            let urlString = String(trimmed[trimmed.index(after: start)..<end])
            return URL(string: urlString)
        }
        return nil
    }
}
