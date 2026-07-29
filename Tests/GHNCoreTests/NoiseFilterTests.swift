import XCTest
@testable import GHNCore

final class NoiseFilterTests: XCTestCase {

    private func makeFilter(includeBots: Bool = false, includeDrafts: Bool = false) -> NoiseFilter {
        NoiseFilter(selfLogin: "octocat", includeBots: includeBots, includeDrafts: includeDrafts)
    }

    // MARK: - Built-in bot list (PLAN.md: Built-in bots)

    func testBuiltInBotLoginsMatchPlan() {
        let expected: Set<String> = [
            "dependabot[bot]", "renovate[bot]", "github-actions[bot]",
            "greenkeeper[bot]", "imgbot[bot]", "prettier[bot]",
            "linkedin-app[bot]", "codecov[bot]", "sonarcloud[bot]",
            "snyk-bot",
        ]
        XCTAssertEqual(NoiseFilter.builtInBots, expected)
    }

    func testIsBotRecognizesBuiltInBotLogins() {
        let filter = makeFilter()
        XCTAssertTrue(filter.isBot(login: "dependabot[bot]", type: "User"))
        XCTAssertTrue(filter.isBot(login: "snyk-bot", type: nil))
        XCTAssertFalse(filter.isBot(login: "octocat", type: "User"))
    }

    func testIsBotRecognizesGitHubBotType() {
        let filter = makeFilter()
        XCTAssertTrue(filter.isBot(login: "some-app", type: "Bot"))
        XCTAssertFalse(filter.isBot(login: "some-user", type: "User"))
    }

    // MARK: - Exclude

    func testExcludesSelfAuthoredItems() {
        let filter = makeFilter()
        XCTAssertFalse(filter.shouldInclude(authorLogin: "octocat", authorType: "User", isDraft: false))
    }

    func testExcludesBuiltInBotAuthoredItems() {
        let filter = makeFilter()
        XCTAssertFalse(filter.shouldInclude(authorLogin: "renovate[bot]", authorType: "User", isDraft: false))
    }

    func testExcludesBotTypeAuthoredItems() {
        let filter = makeFilter()
        XCTAssertFalse(filter.shouldInclude(authorLogin: "random-app", authorType: "Bot", isDraft: false))
    }

    func testExcludesDrafts() {
        let filter = makeFilter()
        XCTAssertFalse(filter.shouldInclude(authorLogin: "someone", authorType: "User", isDraft: true))
    }

    func testIncludesOrdinaryHumanNonDraft() {
        let filter = makeFilter()
        XCTAssertTrue(filter.shouldInclude(authorLogin: "someone", authorType: "User", isDraft: false))
    }

    // MARK: - Re-include via flags

    func testIncludeBotsFlagReIncludesBots() {
        let filter = makeFilter(includeBots: true)
        XCTAssertTrue(filter.shouldInclude(authorLogin: "dependabot[bot]", authorType: "User", isDraft: false))
        XCTAssertTrue(filter.shouldInclude(authorLogin: "random-app", authorType: "Bot", isDraft: false))
    }

    func testIncludeDraftsFlagReIncludesDrafts() {
        let filter = makeFilter(includeDrafts: true)
        XCTAssertTrue(filter.shouldInclude(authorLogin: "someone", authorType: "User", isDraft: true))
    }

    func testSelfIsNeverReIncludedByFlags() {
        let filter = makeFilter(includeBots: true, includeDrafts: true)
        XCTAssertFalse(filter.shouldInclude(authorLogin: "octocat", authorType: "Bot", isDraft: false))
    }
}
