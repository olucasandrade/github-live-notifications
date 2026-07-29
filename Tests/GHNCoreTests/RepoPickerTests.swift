import XCTest
@testable import GHNCore

/// Acceptance tests for T5.2 repo picker policy (PLAN.md + UI-SPEC §3.1).
final class RepoPickerTests: XCTestCase {
    private let selfLogin = "octocat"

    private func repo(
        id: Int,
        name: String,
        ownerLogin: String,
        ownerType: String = "User",
        fork: Bool = false,
        archived: Bool = false
    ) -> GitHubRepository {
        GitHubRepository(
            id: id,
            name: name,
            fullName: "\(ownerLogin)/\(name)",
            owner: .init(login: ownerLogin, type: ownerType),
            fork: fork,
            archived: archived,
            isPrivate: false,
            stargazersCount: 0
        )
    }

    // MARK: - Ownership classification

    func testOwnedWhenOwnerMatchesSelfLogin() {
        let owned = repo(id: 1, name: "mine", ownerLogin: selfLogin)
        XCTAssertEqual(RepoPicker.ownershipKind(of: owned, selfLogin: selfLogin), .owned)
    }

    func testOrgWhenOwnerIsOrganization() {
        let orgRepo = repo(id: 2, name: "platform", ownerLogin: "github", ownerType: "Organization")
        XCTAssertEqual(RepoPicker.ownershipKind(of: orgRepo, selfLogin: selfLogin), .org)
    }

    func testCollaboratorWhenOwnerIsAnotherUser() {
        let collab = repo(id: 3, name: "theirs", ownerLogin: "otherdev")
        XCTAssertEqual(RepoPicker.ownershipKind(of: collab, selfLogin: selfLogin), .collaborator)
    }

    // MARK: - Search

    func testSearchMatchesFullNameCaseInsensitively() {
        let hello = repo(id: 1, name: "Hello-World", ownerLogin: selfLogin)
        XCTAssertTrue(RepoPicker.matchesSearch(hello, query: "hello"))
        XCTAssertTrue(RepoPicker.matchesSearch(hello, query: "WORLD"))
        XCTAssertFalse(RepoPicker.matchesSearch(hello, query: "missing"))
    }

    func testEmptySearchMatchesEverything() {
        let hello = repo(id: 1, name: "Hello-World", ownerLogin: selfLogin)
        XCTAssertTrue(RepoPicker.matchesSearch(hello, query: ""))
        XCTAssertTrue(RepoPicker.matchesSearch(hello, query: "   "))
    }

    // MARK: - Filters

    func testFilterRequiresActiveOwnershipKindAndSearch() {
        let repos = [
            repo(id: 1, name: "mine", ownerLogin: selfLogin),
            repo(id: 2, name: "theirs", ownerLogin: "otherdev"),
            repo(id: 3, name: "platform", ownerLogin: "github", ownerType: "Organization"),
        ]

        let ownedOnly = RepoPicker.filter(
            repos: repos,
            activeFilters: [.owned],
            searchQuery: "",
            selfLogin: selfLogin
        )
        XCTAssertEqual(ownedOnly.map(\.id), [1])

        let searched = RepoPicker.filter(
            repos: repos,
            activeFilters: Set(RepoOwnershipKind.allCases),
            searchQuery: "plat",
            selfLogin: selfLogin
        )
        XCTAssertEqual(searched.map(\.id), [3])
    }

    // MARK: - Default preselect

    func testDefaultPreselectsUpToTwentyOwnedNonForkNonArchived() {
        let repos = (1...30).map { index in
            repo(id: index, name: "repo-\(index)", ownerLogin: selfLogin)
        }

        let selected = RepoPicker.defaultSelectedIDs(from: repos, selfLogin: selfLogin)
        XCTAssertEqual(selected.count, 20)
        XCTAssertEqual(selected, Set(1...20))
    }

    func testDefaultPreselectSkipsForksAndArchivedOwnedRepos() {
        let repos = [
            repo(id: 1, name: "good", ownerLogin: selfLogin),
            repo(id: 2, name: "fork", ownerLogin: selfLogin, fork: true),
            repo(id: 3, name: "old", ownerLogin: selfLogin, archived: true),
            repo(id: 4, name: "collab", ownerLogin: "otherdev"),
        ]

        let selected = RepoPicker.defaultSelectedIDs(from: repos, selfLogin: selfLogin)
        XCTAssertEqual(selected, [1])
    }

    func testDefaultPreselectDoesNotIncludeOrgOrCollaboratorRepos() {
        let repos = [
            repo(id: 1, name: "mine", ownerLogin: selfLogin),
            repo(id: 2, name: "theirs", ownerLogin: "otherdev"),
            repo(id: 3, name: "org", ownerLogin: "acme", ownerType: "Organization"),
        ]

        let selected = RepoPicker.defaultSelectedIDs(from: repos, selfLogin: selfLogin)
        XCTAssertEqual(selected, [1])
    }

    // MARK: - Cap + warning

    func testHardCapIsFifty() {
        XCTAssertEqual(RepoPickerLimits.maxSelected, 50)
        XCTAssertTrue(RepoPicker.canAddSelection(currentCount: 49))
        XCTAssertFalse(RepoPicker.canAddSelection(currentCount: 50))
    }

    func testWarnsAtFortyOrMore() {
        XCTAssertEqual(RepoPickerLimits.warnThreshold, 40)
        XCTAssertFalse(RepoPicker.shouldWarnSelection(currentCount: 39))
        XCTAssertTrue(RepoPicker.shouldWarnSelection(currentCount: 40))
        XCTAssertTrue(RepoPicker.shouldWarnSelection(currentCount: 50))
    }

    func testToggleSelectionRespectsHardCap() {
        var selected = Set((1...50).map { $0 })
        XCTAssertFalse(RepoPicker.toggleSelection(id: 99, selected: &selected))
        XCTAssertFalse(selected.contains(99))

        selected.remove(1)
        XCTAssertTrue(RepoPicker.toggleSelection(id: 99, selected: &selected))
        XCTAssertTrue(selected.contains(99))
    }
}
