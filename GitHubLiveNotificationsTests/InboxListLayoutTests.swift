import GHNCore
@testable import GitHubLiveNotifications
import XCTest

/// Behavioral tests for inbox section grouping and the 20-row cap (UI-SPEC §2.2).
final class InboxListLayoutTests: XCTestCase {
    private func item(id: String, section: InboxSection) -> InboxItem {
        let source: InboxItem.Source
        switch section {
        case .myWork:
            source = .thread(reason: .mention)
        case .activity:
            source = .thread(reason: .comment)
        case .ciAndSecurity:
            source = .thread(reason: .ciActivity)
        case .newOnMyRepos:
            source = .synthetic(.newOnMyRepos)
        case .stars:
            source = .synthetic(.stars)
        }
        return InboxItem(
            id: id,
            title: "Item \(id)",
            repoFullName: "owner/repo",
            url: nil,
            source: source,
            updatedAt: Date()
        )
    }

    func testLayoutOmitsEmptySections() {
        let items = [item(id: "1", section: .myWork)]
        let layout = InboxListLayout.layout(items: items)
        XCTAssertEqual(layout.sections.map(\.section), [.myWork])
    }

    func testLayoutPreservesPlanSectionOrder() {
        let items = [
            item(id: "s", section: .stars),
            item(id: "a", section: .activity),
            item(id: "m", section: .myWork),
        ]
        let layout = InboxListLayout.layout(items: items)
        XCTAssertEqual(layout.sections.map(\.section), [.myWork, .activity, .stars])
    }

    func testLayoutCapsVisibleRowsAtTwenty() {
        let items = (1...25).map { item(id: "\($0)", section: .myWork) }
        let layout = InboxListLayout.layout(items: items)
        let visible = layout.sections.reduce(0) { $0 + $1.visibleItems.count }
        XCTAssertEqual(visible, 20)
        XCTAssertEqual(layout.overflowCount, 5)
    }

    func testLayoutOverflowSpansLaterSections() {
        let myWork = (1...15).map { item(id: "m\($0)", section: .myWork) }
        let activity = (1...10).map { item(id: "a\($0)", section: .activity) }
        let layout = InboxListLayout.layout(items: myWork + activity)
        XCTAssertEqual(layout.sections.count, 2)
        XCTAssertEqual(layout.sections[0].visibleItems.count, 15)
        XCTAssertEqual(layout.sections[1].visibleItems.count, 5)
        XCTAssertEqual(layout.overflowCount, 5)
    }
}
