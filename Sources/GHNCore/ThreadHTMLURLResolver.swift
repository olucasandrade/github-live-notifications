import Foundation

/// Resolves a notification thread's subject API URL to a browser-openable `html_url`.
///
/// Each thread is fetched at most once; results are cached keyed by thread ID.
public final class ThreadHTMLURLResolver: @unchecked Sendable {

    private let client: GitHubClient
    private let lock = NSLock()
    private var cache: [String: URL] = [:]

    public init(client: GitHubClient) {
        self.client = client
    }

    /// Returns the web URL for `thread`, using cache, API fetch, or fallback heuristics.
    public func resolve(thread: NotificationThread) async -> URL? {
        if let cached = cachedURL(for: thread.id) {
            return cached
        }

        let resolved = await resolveUncached(thread: thread)

        if let resolved {
            storeCachedURL(resolved, for: thread.id)
        }
        return resolved
    }

    private func cachedURL(for threadID: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return cache[threadID]
    }

    private func storeCachedURL(_ url: URL, for threadID: String) {
        lock.lock()
        defer { lock.unlock() }
        cache[threadID] = url
    }

    private func resolveUncached(thread: NotificationThread) async -> URL? {
        if let webURL = Self.existingWebURL(from: thread.subject.url) {
            return webURL
        }
        guard let subjectURL = URL(string: thread.subject.url) else {
            return nil
        }

        if let fetched = await fetchHTMLURL(from: subjectURL) {
            return fetched
        }
        return Self.fallbackHTMLURL(fromSubjectAPIURL: subjectURL)
    }

    private func fetchHTMLURL(from subjectURL: URL) async -> URL? {
        do {
            let (data, http) = try await client.performGetURL(subjectURL)
            guard (200...299).contains(http.statusCode) else { return nil }
            let payload = try GitHubClient.jsonDecoder.decode(SubjectHTMLURL.self, from: data)
            return payload.htmlURL
        } catch {
            return nil
        }
    }

    /// Subject payloads across issue/PR/commit/etc. all expose `html_url`.
    private struct SubjectHTMLURL: Decodable {
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case htmlURL = "html_url"
        }
    }

    /// Returns `subjectURL` when it is already a github.com web link.
    static func existingWebURL(from subjectURL: String) -> URL? {
        guard let url = URL(string: subjectURL),
              let host = url.host?.lowercased(),
              host == "github.com" else {
            return nil
        }
        return url
    }

    /// Fallback when the subject API fetch fails or omits `html_url`.
    ///
    /// Heuristics (best-effort; cannot infer release IDs or other opaque resources):
    /// 1. Require `api.github.com` host and a path starting with `/repos/{owner}/{repo}/`.
    /// 2. Strip the `/repos/` prefix so the web path is `/{owner}/{repo}/…`.
    /// 3. Map API resource segments to web paths: `pulls` → `pull`, `commits` → `commit`.
    /// 4. Rebuild `https://github.com/{owner}/{repo}/{rest…}`; leave other segments unchanged
    ///    (e.g. `issues`, `discussions`, `security/advisories`).
    static func fallbackHTMLURL(fromSubjectAPIURL subjectURL: URL) -> URL? {
        guard subjectURL.host?.lowercased() == "api.github.com" else { return nil }

        let parts = subjectURL.path.split(separator: "/").map(String.init)
        guard parts.count >= 4, parts[0] == "repos" else { return nil }

        let owner = parts[1]
        let repo = parts[2]
        var resourceParts = Array(parts.dropFirst(3))
        guard !resourceParts.isEmpty else { return nil }

        if resourceParts[0] == "pulls" {
            resourceParts[0] = "pull"
        } else if resourceParts[0] == "commits" {
            resourceParts[0] = "commit"
        }

        let webPath = ([owner, repo] + resourceParts).joined(separator: "/")
        return URL(string: "https://github.com/\(webPath)")
    }
}
