import Foundation

/// Reason filtering (PLAN.md: Reasons) — notification threads are shown only
/// when their reason is in the enabled set. The full reason set is enabled by
/// default; each reason is individually toggleable in settings.
///
/// Synthetic inbox items (new-on-my-repos, stars) have no reason and always
/// pass through — their visibility is controlled by their own mechanisms.
public struct ReasonFilter: Equatable {
    /// Reasons whose threads are shown in the inbox.
    public var enabledReasons: Set<NotificationReason>

    public init(enabledReasons: Set<NotificationReason> = Set(NotificationReason.allCases)) {
        self.enabledReasons = enabledReasons
    }

    public func isEnabled(_ reason: NotificationReason) -> Bool {
        enabledReasons.contains(reason)
    }

    /// Keeps threads whose reason is enabled and all synthetic items,
    /// preserving order.
    public func filter(_ items: [InboxItem]) -> [InboxItem] {
        items.filter { item in
            switch item.source {
            case .thread(let reason):
                return isEnabled(reason)
            case .synthetic:
                return true
            }
        }
    }
}
