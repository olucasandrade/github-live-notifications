import AppKit
import SwiftUI

// MARK: - Corner radius (UI-SPEC §1.3)

enum GHNRadius {
    /// Panel outer chrome.
    static let panelOuter: CGFloat = 14
    /// Nested groups inside the panel or Settings form.
    static let innerGroup: CGFloat = 10
    /// Pills and chips.
    static let pill: CGFloat = 6
    /// Icon wells.
    static let iconWell: CGFloat = 7
}

// MARK: - Typography (UI-SPEC §1.2)

enum GHNFont {
    /// Settings header brand wordmark only.
    static let brand = Font.system(size: 22, weight: .semibold, design: .rounded)

    /// Panel title and section headers.
    static let panelTitle = Font.system(size: 13, weight: .semibold)

    /// Notification row title.
    static let rowTitle = Font.system(size: 13, weight: .regular)

    /// Repo, reason, relative time.
    static let meta = Font.system(size: 11, weight: .regular)

    /// Counts, timestamps, badges.
    static let mono = Font.system(size: 11, weight: .medium, design: .monospaced)

    /// Empty-state headline.
    static let emptyHeadline = Font.system(size: 15, weight: .medium)
}

// MARK: - Color (UI-SPEC §1.1)

enum GHNColor {
    /// Panel + Settings root — system window background.
    static let surfaceCanvas = Color(nsColor: .windowBackgroundColor)

    /// Nested groups (double-bezel inner fill).
    static let surfaceElevated = Color("surface.elevated")

    /// Separators and outer bezel ring.
    static let surfaceHairline = Color("surface.hairline")

    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    /// Single accent: unread pip, primary buttons, focus.
    static let accentSignal = Color("accent.signal")

    static let stateDanger = Color(nsColor: .systemRed)
    static let stateWarn = Color(nsColor: .systemOrange)
}
