import SwiftUI

/// UI-SPEC §1.1 color tokens for the app shell.
enum DesignTokens {
    /// `accent.signal` — light `#1A7F37`, dark `#3FB950`.
    static func accentSignal(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0x3F / 255, green: 0xB9 / 255, blue: 0x50 / 255)
        default:
            return Color(red: 0x1A / 255, green: 0x7F / 255, blue: 0x37 / 255)
        }
    }
}
