import Foundation

// MARK: - Response models

public struct GitHubUser: Decodable, Equatable, Sendable {
    public let login: String
    public let id: Int

    public init(login: String, id: Int) {
        self.login = login
        self.id = id
    }
}

public struct NotificationThread: Decodable, Equatable, Sendable {
    public struct Subject: Decodable, Equatable, Sendable {
        public let title: String
        public let url: String
        public let type: String
    }

    public struct Repository: Decodable, Equatable, Sendable {
        public let fullName: String

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
        }
    }

    public let id: String
    public let reason: NotificationReason
    public let subject: Subject
    public let repository: Repository
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, reason, subject, repository
        case updatedAt = "updated_at"
    }
}

/// Repository payload from `GET /user/repos` or `GET /repos/{owner}/{repo}`.
public struct GitHubRepository: Decodable, Equatable, Sendable {
    public struct Owner: Decodable, Equatable, Sendable {
        public let login: String
        public let type: String

        public init(login: String, type: String = "User") {
            self.login = login
            self.type = type
        }

        enum CodingKeys: String, CodingKey {
            case login, type
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            login = try container.decode(String.self, forKey: .login)
            type = try container.decodeIfPresent(String.self, forKey: .type) ?? "User"
        }
    }

    public let id: Int
    public let name: String
    public let fullName: String
    public let owner: Owner
    public let fork: Bool
    public let archived: Bool
    public let isPrivate: Bool
    public let stargazersCount: Int

    public var ownerLogin: String { owner.login }

    public init(
        id: Int,
        name: String,
        fullName: String,
        owner: Owner,
        fork: Bool,
        archived: Bool,
        isPrivate: Bool,
        stargazersCount: Int
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.owner = owner
        self.fork = fork
        self.archived = archived
        self.isPrivate = isPrivate
        self.stargazersCount = stargazersCount
    }

    enum CodingKeys: String, CodingKey {
        case id, name, owner, fork, archived
        case fullName = "full_name"
        case isPrivate = "private"
        case stargazersCount = "stargazers_count"
    }
}

public struct PullRequestSummary: Decodable, Equatable, Sendable {
    public struct Author: Decodable, Equatable, Sendable {
        public let login: String
        public let type: String
    }

    public let id: Int
    public let number: Int
    public let title: String
    public let htmlURL: URL
    public let user: Author
    public let draft: Bool

    public var authorLogin: String { user.login }
    public var authorType: String { user.type }

    enum CodingKeys: String, CodingKey {
        case id, number, title, user, draft
        case htmlURL = "html_url"
    }
}

public struct IssueSummary: Decodable, Equatable, Sendable {
    public struct Author: Decodable, Equatable, Sendable {
        public let login: String
        public let type: String
    }

    public let id: Int
    public let number: Int
    public let title: String
    public let htmlURL: URL
    public let user: Author

    public var authorLogin: String { user.login }
    public var authorType: String { user.type }

    enum CodingKeys: String, CodingKey {
        case id, number, title, user
        case htmlURL = "html_url"
    }
}

// MARK: - Endpoints

extension GitHubClient {

    public func fetchUser() async throws -> FetchResult<GitHubUser> {
        try await get("/user", as: GitHubUser.self)
    }

    /// `GET /notifications?all=false`, at most two pages (≤100 threads).
    public func fetchNotifications() async throws -> FetchResult<[NotificationThread]> {
        let firstPath = "/notifications?all=false&per_page=50"
        let (firstData, firstHTTP) = try await performGet(firstPath)
        let pollInterval = firstHTTP.value(forHTTPHeaderField: "X-Poll-Interval").flatMap(TimeInterval.init)

        switch firstHTTP.statusCode {
        case 304:
            return .notModified(pollInterval: pollInterval)
        case 200...299:
            var threads = try Self.jsonDecoder.decode([NotificationThread].self, from: firstData)
            if let etag = firstHTTP.value(forHTTPHeaderField: "ETag"),
               let url = URL(string: firstPath, relativeTo: baseURL) {
                storeETag(etag, for: url)
            }
            if let nextURL = Self.nextPageURL(from: firstHTTP.value(forHTTPHeaderField: "Link")) {
                let (page2Data, page2HTTP) = try await performGetURL(nextURL)
                guard (200...299).contains(page2HTTP.statusCode) else {
                    throw mapHTTPError(status: page2HTTP.statusCode, response: page2HTTP)
                }
                let page2 = try Self.jsonDecoder.decode([NotificationThread].self, from: page2Data)
                threads.append(contentsOf: page2)
            }
            let etag = firstHTTP.value(forHTTPHeaderField: "ETag")
            return .fresh(body: threads, etag: etag, pollInterval: pollInterval)
        default:
            throw mapHTTPError(status: firstHTTP.statusCode, response: firstHTTP)
        }
    }

    public func fetchUserRepos() async throws -> FetchResult<[GitHubRepository]> {
        try await get("/user/repos?per_page=100", as: [GitHubRepository].self)
    }

    public func fetchRepo(owner: String, name: String) async throws -> FetchResult<GitHubRepository> {
        try await get("/repos/\(owner)/\(name)", as: GitHubRepository.self)
    }

    public func fetchPulls(owner: String, name: String) async throws -> FetchResult<[PullRequestSummary]> {
        try await get("/repos/\(owner)/\(name)/pulls?state=open&per_page=100", as: [PullRequestSummary].self)
    }

    /// `PATCH /notifications/threads/{id}` — marks one thread read (205 Reset Content).
    public func markThreadRead(threadID: String) async throws {
        try await patch("/notifications/threads/\(threadID)")
    }

    /// `PUT /notifications` — marks all notification threads read for the user.
    public func markAllNotificationsRead() async throws {
        try await put("/notifications")
    }

    /// Open issues only; entries that include `pull_request` are dropped (PR dupes).
    public func fetchIssues(owner: String, name: String) async throws -> FetchResult<[IssueSummary]> {
        let result = try await get(
            "/repos/\(owner)/\(name)/issues?state=open&per_page=100",
            as: [RawIssue].self
        )
        switch result {
        case .notModified(let pollInterval):
            return .notModified(pollInterval: pollInterval)
        case .fresh(let raw, let etag, let pollInterval):
            let issues = raw.compactMap(\.issue)
            return .fresh(body: issues, etag: etag, pollInterval: pollInterval)
        }
    }
}

// MARK: - Issue list decoding (skip PR dupes)

private struct RawIssue: Decodable {
    struct PullRequestLink: Decodable {
        let url: String
    }

    let issue: IssueSummary?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if try container.decodeIfPresent(PullRequestLink.self, forKey: .pullRequest) != nil {
            issue = nil
            return
        }
        issue = try IssueSummary(from: decoder)
    }

    enum CodingKeys: String, CodingKey {
        case pullRequest = "pull_request"
    }
}
