import XCTest
@testable import GHNCore

final class DomainModelTests: XCTestCase {

    // MARK: - NotificationReason → InboxSection (PLAN.md: Menu sections ↔ reasons)

    func testMyWorkReasonsMapToMyWorkSection() {
        let reasons: [NotificationReason] = [.author, .reviewRequested, .assign, .mention, .teamMention]
        for reason in reasons {
            XCTAssertEqual(reason.section, .myWork, "\(reason) should map to My work")
        }
    }

    func testActivityReasonsMapToActivitySection() {
        let reasons: [NotificationReason] = [.comment, .stateChange, .manual, .subscribed]
        for reason in reasons {
            XCTAssertEqual(reason.section, .activity, "\(reason) should map to Activity")
        }
    }

    func testCIAndSecurityReasonsMapToCIAndSecuritySection() {
        let reasons: [NotificationReason] = [.ciActivity, .securityAlert]
        for reason in reasons {
            XCTAssertEqual(reason.section, .ciAndSecurity, "\(reason) should map to CI & security")
        }
    }

    func testEveryReasonMapsToAThreadSection() {
        // Synthetic sections are never produced by a thread reason.
        for reason in NotificationReason.allCases {
            XCTAssertFalse([InboxSection.newOnMyRepos, .stars].contains(reason.section),
                           "\(reason) must not map to a synthetic section")
        }
    }

    func testReasonRawValuesMatchGitHubAPIStrings() {
        XCTAssertEqual(NotificationReason.reviewRequested.rawValue, "review_requested")
        XCTAssertEqual(NotificationReason.teamMention.rawValue, "team_mention")
        XCTAssertEqual(NotificationReason.ciActivity.rawValue, "ci_activity")
        XCTAssertEqual(NotificationReason.securityAlert.rawValue, "security_alert")
        XCTAssertEqual(NotificationReason.stateChange.rawValue, "state_change")
        XCTAssertEqual(NotificationReason.author.rawValue, "author")
        XCTAssertEqual(NotificationReason.assign.rawValue, "assign")
        XCTAssertEqual(NotificationReason.mention.rawValue, "mention")
        XCTAssertEqual(NotificationReason.comment.rawValue, "comment")
        XCTAssertEqual(NotificationReason.manual.rawValue, "manual")
        XCTAssertEqual(NotificationReason.subscribed.rawValue, "subscribed")
    }

    // MARK: - InboxItem sources

    func testThreadItemDerivesSectionFromReason() {
        let item = InboxItem(
            id: "thread-1",
            title: "Fix flaky test",
            repoFullName: "octo/repo",
            url: URL(string: "https://github.com/octo/repo/pull/1"),
            source: .thread(reason: .reviewRequested),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(item.section, .myWork)
    }

    func testSyntheticNewOnReposItemMapsToNewOnMyReposSection() {
        let item = InboxItem(
            id: "synthetic-pr-1",
            title: "New PR: Add feature",
            repoFullName: "octo/repo",
            url: URL(string: "https://github.com/octo/repo/pull/2"),
            source: .synthetic(.newOnMyRepos),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(item.section, .newOnMyRepos)
    }

    func testSyntheticStarsItemMapsToStarsSection() {
        let item = InboxItem(
            id: "synthetic-stars-1",
            title: "octo/repo: +12 stars",
            repoFullName: "octo/repo",
            url: URL(string: "https://github.com/octo/repo/stargazers"),
            source: .synthetic(.stars),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(item.section, .stars)
    }

    func testInboxItemIsEquatable() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = InboxItem(id: "1", title: "t", repoFullName: "o/r",
                          url: nil, source: .thread(reason: .mention), updatedAt: date)
        let b = InboxItem(id: "1", title: "t", repoFullName: "o/r",
                          url: nil, source: .thread(reason: .mention), updatedAt: date)
        let c = InboxItem(id: "2", title: "t", repoFullName: "o/r",
                          url: nil, source: .thread(reason: .mention), updatedAt: date)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - MonitoredRepo

    func testMonitoredRepoFullNameAndEquality() {
        let repo = MonitoredRepo(owner: "octo", name: "repo")
        XCTAssertEqual(repo.fullName, "octo/repo")
        XCTAssertEqual(repo, MonitoredRepo(owner: "octo", name: "repo"))
        XCTAssertNotEqual(repo, MonitoredRepo(owner: "octo", name: "other"))
    }

    func testModelsAreCodable() throws {
        let repo = MonitoredRepo(owner: "octo", name: "repo")
        let data = try JSONEncoder().encode(repo)
        XCTAssertEqual(try JSONDecoder().decode(MonitoredRepo.self, from: data), repo)

        let item = InboxItem(id: "1", title: "t", repoFullName: "o/r",
                             url: URL(string: "https://github.com/o/r"),
                             source: .synthetic(.stars),
                             updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let itemData = try JSONEncoder().encode(item)
        XCTAssertEqual(try JSONDecoder().decode(InboxItem.self, from: itemData), item)
    }
}
