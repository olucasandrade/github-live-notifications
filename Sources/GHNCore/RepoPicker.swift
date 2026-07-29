import Foundation

/// Ownership bucket for repo-picker filters (UI-SPEC §3.1).
public enum RepoOwnershipKind: String, CaseIterable, Sendable {
    case owned
    case collaborator
    case org
}

/// Hard limits for monitored repositories (PLAN.md + UI-SPEC §3.1).
public enum RepoPickerLimits {
    public static let maxSelected = 50
    public static let warnThreshold = 40
    public static let defaultPreselectMax = 20
}

/// Pure repo-picker policy: filters, search, defaults, and selection cap.
public enum RepoPicker {
    public static func ownershipKind(of repo: GitHubRepository, selfLogin: String) -> RepoOwnershipKind {
        if repo.owner.login == selfLogin {
            return .owned
        }
        if repo.owner.type == "Organization" {
            return .org
        }
        return .collaborator
    }

    public static func matchesSearch(_ repo: GitHubRepository, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let needle = trimmed.lowercased()
        return repo.fullName.lowercased().contains(needle)
            || repo.name.lowercased().contains(needle)
    }

    public static func filter(
        repos: [GitHubRepository],
        activeFilters: Set<RepoOwnershipKind>,
        searchQuery: String,
        selfLogin: String
    ) -> [GitHubRepository] {
        repos.filter { repo in
            matchesSearch(repo, query: searchQuery)
                && activeFilters.contains(ownershipKind(of: repo, selfLogin: selfLogin))
        }
    }

    /// Default selection: up to 20 owned, non-fork, non-archived repos (PLAN.md).
    public static func defaultSelectedIDs(
        from repos: [GitHubRepository],
        selfLogin: String
    ) -> Set<Int> {
        let candidates = repos.filter { repo in
            ownershipKind(of: repo, selfLogin: selfLogin) == .owned
                && !repo.fork
                && !repo.archived
        }
        return Set(candidates.prefix(RepoPickerLimits.defaultPreselectMax).map(\.id))
    }

    public static func canAddSelection(currentCount: Int) -> Bool {
        currentCount < RepoPickerLimits.maxSelected
    }

    public static func shouldWarnSelection(currentCount: Int) -> Bool {
        currentCount >= RepoPickerLimits.warnThreshold
    }

    /// Toggles a repo in `selected`. Returns whether the selection changed.
    @discardableResult
    public static func toggleSelection(id: Int, selected: inout Set<Int>) -> Bool {
        if selected.contains(id) {
            selected.remove(id)
            return true
        }
        guard canAddSelection(currentCount: selected.count) else { return false }
        selected.insert(id)
        return true
    }

    public static func monitoredRepos(
        from repos: [GitHubRepository],
        selectedIDs: Set<Int>
    ) -> [MonitoredRepo] {
        repos
            .filter { selectedIDs.contains($0.id) }
            .map { MonitoredRepo(owner: $0.ownerLogin, name: $0.name) }
    }
}
