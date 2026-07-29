import Foundation

public enum GitHubClientError: Error, Equatable {
    case invalidURL(String)
    case unexpectedResponse
    case httpStatus(Int)
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

    public init(
        baseURL: URL = URL(string: "https://api.github.com")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    /// GET `baseURL + path`, revalidating with a stored ETag when one exists.
    public func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> FetchResult<T> {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw GitHubClientError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let etag = storedETag(for: url) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubClientError.unexpectedResponse
        }

        let pollInterval = http.value(forHTTPHeaderField: "X-Poll-Interval").flatMap(TimeInterval.init)

        switch http.statusCode {
        case 304:
            return .notModified(pollInterval: pollInterval)
        case 200...299:
            let body = try JSONDecoder().decode(T.self, from: data)
            let etag = http.value(forHTTPHeaderField: "ETag")
            if let etag {
                storeETag(etag, for: url)
            }
            return .fresh(body: body, etag: etag, pollInterval: pollInterval)
        default:
            throw GitHubClientError.httpStatus(http.statusCode)
        }
    }

    // MARK: - ETag store (in-memory; persistence lands with the cache store)

    func storedETag(for url: URL) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return etags[url]
    }

    private func storeETag(_ etag: String, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        etags[url] = etag
    }
}
