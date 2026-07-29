import Foundation

/// GitHub notification thread reasons (`reason` field of the notifications API).
/// Full set, each toggleable — raw values match the API strings.
public enum NotificationReason: String, Codable, CaseIterable, Equatable {
    case assign
    case author
    case ciActivity = "ci_activity"
    case comment
    case manual
    case mention
    case reviewRequested = "review_requested"
    case securityAlert = "security_alert"
    case stateChange = "state_change"
    case subscribed
    case teamMention = "team_mention"

    /// Menu section this reason belongs to (PLAN.md: Menu sections ↔ reasons).
    public var section: InboxSection {
        switch self {
        case .author, .reviewRequested, .assign, .mention, .teamMention:
            return .myWork
        case .comment, .stateChange, .manual, .subscribed:
            return .activity
        case .ciActivity, .securityAlert:
            return .ciAndSecurity
        }
    }
}

/// Sections of the inbox menu panel.
public enum InboxSection: String, Codable, CaseIterable, Equatable {
    case myWork
    case activity
    case ciAndSecurity
    case newOnMyRepos
    case stars
}

/// One row in the inbox. Threads come from the notifications API and carry a
/// reason; synthetic items come from repo-poll diffs (new PRs/issues, star deltas).
public struct InboxItem: Equatable, Codable {
    public enum SyntheticSource: String, Codable, Equatable {
        case newOnMyRepos
        case stars
    }

    public enum Source: Equatable, Codable {
        case thread(reason: NotificationReason)
        case synthetic(SyntheticSource)
    }

    public let id: String
    public let title: String
    public let repoFullName: String
    public let url: URL?
    public let source: Source
    public let updatedAt: Date

    public init(id: String, title: String, repoFullName: String,
                url: URL?, source: Source, updatedAt: Date) {
        self.id = id
        self.title = title
        self.repoFullName = repoFullName
        self.url = url
        self.source = source
        self.updatedAt = updatedAt
    }

    public var section: InboxSection {
        switch source {
        case .thread(let reason):
            return reason.section
        case .synthetic(.newOnMyRepos):
            return .newOnMyRepos
        case .synthetic(.stars):
            return .stars
        }
    }
}

/// A repository selected for polling (stars + open PRs + open issues).
public struct MonitoredRepo: Equatable, Codable, Hashable {
    public let owner: String
    public let name: String

    public init(owner: String, name: String) {
        self.owner = owner
        self.name = name
    }

    public var fullName: String { "\(owner)/\(name)" }
}
