import GHNCore
import SwiftUI

extension InboxSection {
    /// PLAN.md section order (`InboxSection.allCases`).
    static var displayOrder: [InboxSection] { InboxSection.allCases }

    var title: String {
        switch self {
        case .myWork: return "My work"
        case .activity: return "Activity"
        case .ciAndSecurity: return "CI & security"
        case .newOnMyRepos: return "New on my repos"
        case .stars: return "Stars"
        }
    }

    var symbolName: String {
        switch self {
        case .myWork: return "tray.full"
        case .activity: return "bubble.left.and.bubble.right"
        case .ciAndSecurity: return "checkmark.shield"
        case .newOnMyRepos: return "folder.badge.plus"
        case .stars: return "star.fill"
        }
    }
}

extension NotificationReason {
    var displayLabel: String {
        switch self {
        case .assign: return "assign"
        case .author: return "author"
        case .ciActivity: return "CI"
        case .comment: return "comment"
        case .manual: return "manual"
        case .mention: return "mention"
        case .reviewRequested: return "review"
        case .securityAlert: return "security"
        case .stateChange: return "state change"
        case .subscribed: return "subscribed"
        case .teamMention: return "team mention"
        }
    }
}

extension InboxItem {
    var reasonLabel: String {
        switch source {
        case .thread(let reason):
            return reason.displayLabel
        case .synthetic(.newOnMyRepos):
            return "new"
        case .synthetic(.stars):
            return "stars"
        }
    }
}
