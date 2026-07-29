import GHNCore
import SwiftUI

/// Single inbox row (UI-SPEC §2.2 row anatomy).
struct InboxRowView: View {
    let item: InboxItem
    let isUnread: Bool
    var now: Date = Date()

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(isUnread ? GHNColor.accentSignal : Color.clear)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(GHNFont.rowTitle)
                    .foregroundStyle(GHNColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 0) {
                    Text(item.repoFullName)
                    Text(" · ")
                    Text(item.reasonLabel)
                    Text(" · ")
                    Text(RelativeTimeFormat.compact(since: item.updatedAt, now: now))
                        .font(GHNFont.mono)
                }
                .font(GHNFont.meta)
                .foregroundStyle(GHNColor.textSecondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: GHNRadius.pill, style: .continuous)
                .fill(isHovered ? GHNColor.surfaceElevated.opacity(0.65) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

enum RelativeTimeFormat {
    static func compact(since date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "\(max(1, seconds))s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}
