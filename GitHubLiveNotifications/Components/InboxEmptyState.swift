import SwiftUI

/// Empty inbox body (UI-SPEC §2.4).
struct InboxEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(GHNColor.textSecondary)
            Text("You're caught up")
                .font(GHNFont.emptyHeadline)
                .foregroundStyle(GHNColor.textPrimary)
            Text("New signals will land here when something needs you.")
                .font(GHNFont.meta)
                .foregroundStyle(GHNColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
