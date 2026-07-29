import Foundation

/// Menu bar badge label text (UI-SPEC §2.5).
enum MenuBarBadgeFormat {
    /// Returns badge text for `count`, or `nil` when there is nothing to show.
    static func display(count: Int) -> String? {
        guard count > 0 else { return nil }
        if count > 99 { return "99+" }
        return String(count)
    }
}
