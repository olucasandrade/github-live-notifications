import Foundation
import GHNCore

/// Groups inbox items into PLAN sections and applies the global 20-row cap (UI-SPEC §2.2).
struct InboxListLayout {
    struct SectionSlice: Equatable {
        let section: InboxSection
        let visibleItems: [InboxItem]
        let totalCount: Int
    }

    struct Result: Equatable {
        let sections: [SectionSlice]
        let overflowCount: Int
    }

    static let maxVisibleRows = 20

    static func layout(items: [InboxItem]) -> Result {
        let grouped = Dictionary(grouping: items, by: \.section)
        var remaining = maxVisibleRows
        var overflowCount = 0
        var sections: [SectionSlice] = []

        for section in InboxSection.allCases {
            guard var allItems = grouped[section], !allItems.isEmpty else { continue }
            allItems.sort { $0.updatedAt > $1.updatedAt }

            if remaining == 0 {
                overflowCount += allItems.count
                continue
            }

            let visibleItems = Array(allItems.prefix(remaining))
            sections.append(
                SectionSlice(section: section, visibleItems: visibleItems, totalCount: allItems.count)
            )
            overflowCount += allItems.count - visibleItems.count
            remaining -= visibleItems.count
        }

        return Result(sections: sections, overflowCount: overflowCount)
    }
}
