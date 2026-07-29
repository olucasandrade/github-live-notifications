import Foundation

/// Noise filtering (PLAN.md: Noise) — excludes self-authored items, bots, and
/// drafts unless the user re-includes them via the settings checkboxes.
public struct NoiseFilter: Equatable {
    /// Built-in bot logins (PLAN.md: Built-in bots).
    public static let builtInBots: Set<String> = [
        "dependabot[bot]",
        "renovate[bot]",
        "github-actions[bot]",
        "greenkeeper[bot]",
        "imgbot[bot]",
        "prettier[bot]",
        "linkedin-app[bot]",
        "codecov[bot]",
        "sonarcloud[bot]",
        "snyk-bot",
    ]

    /// Login of the authenticated user; self-authored items are always excluded.
    public var selfLogin: String?
    /// Include-bots checkbox (default off).
    public var includeBots: Bool
    /// Include-drafts checkbox (default off).
    public var includeDrafts: Bool

    public init(selfLogin: String? = nil, includeBots: Bool = false, includeDrafts: Bool = false) {
        self.selfLogin = selfLogin
        self.includeBots = includeBots
        self.includeDrafts = includeDrafts
    }

    /// A login is a bot if it is on the built-in list or GitHub reports `type == "Bot"`.
    public func isBot(login: String?, type: String?) -> Bool {
        if type == "Bot" { return true }
        if let login, NoiseFilter.builtInBots.contains(login) { return true }
        return false
    }

    /// Whether an item authored by `authorLogin` should be shown in the inbox.
    public func shouldInclude(authorLogin: String?, authorType: String?, isDraft: Bool) -> Bool {
        if let selfLogin, authorLogin == selfLogin { return false }
        if !includeBots, isBot(login: authorLogin, type: authorType) { return false }
        if !includeDrafts, isDraft { return false }
        return true
    }
}
