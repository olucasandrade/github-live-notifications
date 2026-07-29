import GHNCore
import SwiftUI

/// Sectioned inbox body with empty state and overflow footer (UI-SPEC §2.2).
struct InboxListView: View {
    let items: [InboxItem]
    let isUnread: (InboxItem) -> Bool

    private var layout: InboxListLayout.Result {
        InboxListLayout.layout(items: items)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                InboxEmptyState()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(layout.sections.enumerated()), id: \.offset) { _, slice in
                        InboxSectionHeader(section: slice.section, count: slice.totalCount)

                        ForEach(slice.visibleItems, id: \.id) { item in
                            InboxRowView(item: item, isUnread: isUnread(item))
                        }
                    }

                    if layout.overflowCount > 0 {
                        Text("\(layout.overflowCount) more on GitHub…")
                            .font(GHNFont.meta)
                            .foregroundStyle(GHNColor.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
