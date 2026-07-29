import GHNCore
import SwiftUI

/// Section header: symbol + title + mono count (UI-SPEC §2.2).
struct InboxSectionHeader: View {
    let section: InboxSection
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: section.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GHNColor.textSecondary)
                .frame(width: 14)

            Text(section.title)
                .font(GHNFont.panelTitle)
                .foregroundStyle(GHNColor.textPrimary)

            Spacer(minLength: 8)

            Text("\(count)")
                .font(GHNFont.mono)
                .foregroundStyle(GHNColor.textTertiary)
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}
