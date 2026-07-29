import XCTest
@testable import GHNCore

final class ReasonFilterTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeThread(_ reason: NotificationReason, id: String? = nil) -> InboxItem {
        InboxItem(
            id: id ?? "thread-\(reason.rawValue)",
            title: "title",
            repoFullName: "octocat/hello",
            url: nil,
            source: .thread(reason: reason),
            updatedAt: now
        )
    }

    private func makeSynthetic(_ source: InboxItem.SyntheticSource, id: String) -> InboxItem {
        InboxItem(
            id: id,
            title: "title",
            repoFullName: "octocat/hello",
            url: nil,
            source: .synthetic(source),
            updatedAt: now
        )
    }

    // MARK: - Default

    func testDefaultEnablesAllReasons() {
        let filter = ReasonFilter()
        XCTAssertEqual(filter.enabledReasons, Set(NotificationReason.allCases))
        for reason in NotificationReason.allCases {
            XCTAssertTrue(filter.isEnabled(reason), "\(reason) should be enabled by default")
        }
    }

    // MARK: - Kitchen-sink matrix: every reason × enabled/disabled

    func testEveryReasonPassesWhenItIsTheOnlyOneEnabled() {
        for reason in NotificationReason.allCases {
            let filter = ReasonFilter(enabledReasons: [reason])
            XCTAssertEqual(filter.filter([makeThread(reason)]), [makeThread(reason)],
                           "\(reason) should pass when it is the only enabled reason")
        }
    }

    func testEveryReasonIsDroppedWhenItIsTheOnlyOneDisabled() {
        for reason in NotificationReason.allCases {
            let filter = ReasonFilter(enabledReasons: Set(NotificationReason.allCases).subtracting([reason]))
            XCTAssertTrue(filter.filter([makeThread(reason)]).isEmpty,
                          "\(reason) should be dropped when it is the only disabled reason")
        }
    }

    func testEmptyEnabledSetDropsEveryThread() {
        let filter = ReasonFilter(enabledReasons: [])
        let threads = NotificationReason.allCases.map { makeThread($0) }
        XCTAssertTrue(filter.filter(threads).isEmpty)
    }

    func testFullEnabledSetKeepsEveryThread() {
        let filter = ReasonFilter(enabledReasons: Set(NotificationReason.allCases))
        let threads = NotificationReason.allCases.map { makeThread($0) }
        XCTAssertEqual(filter.filter(threads), threads)
    }

    // MARK: - Mixed lists

    func testMixedListKeepsOnlyEnabledReasonsInOrder() {
        let filter = ReasonFilter(enabledReasons: [.mention, .securityAlert])
        let items = [
            makeThread(.assign, id: "1"),
            makeThread(.mention, id: "2"),
            makeThread(.ciActivity, id: "3"),
            makeThread(.securityAlert, id: "4"),
            makeThread(.subscribed, id: "5"),
        ]
        XCTAssertEqual(filter.filter(items).map(\.id), ["2", "4"])
    }

    // MARK: - Synthetic items are not reason-filtered

    func testSyntheticItemsAlwaysPassRegardlessOfEnabledReasons() {
        for enabled: Set<NotificationReason> in [[], [.mention], Set(NotificationReason.allCases)] {
            let filter = ReasonFilter(enabledReasons: enabled)
            let synthetics = [
                makeSynthetic(.newOnMyRepos, id: "new-1"),
                makeSynthetic(.stars, id: "stars-1"),
            ]
            XCTAssertEqual(filter.filter(synthetics), synthetics)
        }
    }

    func testMixedThreadsAndSynthetics() {
        let filter = ReasonFilter(enabledReasons: [.author])
        let items = [
            makeThread(.comment, id: "t1"),
            makeSynthetic(.newOnMyRepos, id: "s1"),
            makeThread(.author, id: "t2"),
            makeSynthetic(.stars, id: "s2"),
        ]
        XCTAssertEqual(filter.filter(items).map(\.id), ["s1", "t2", "s2"])
    }

    // MARK: - isEnabled

    func testIsEnabledReflectsEnabledSet() {
        let filter = ReasonFilter(enabledReasons: [.reviewRequested, .teamMention])
        XCTAssertTrue(filter.isEnabled(.reviewRequested))
        XCTAssertTrue(filter.isEnabled(.teamMention))
        XCTAssertFalse(filter.isEnabled(.assign))
    }
}
