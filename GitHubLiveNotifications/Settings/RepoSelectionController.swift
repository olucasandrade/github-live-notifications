import Foundation
import GHNCore

/// Loads `/user/repos` and tracks monitored-repo selection for Settings (T5.2).
@MainActor
final class RepoSelectionController: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var repos: [GitHubRepository] = []
    @Published private(set) var selectedIDs: Set<Int> = []
    @Published private(set) var loadState: LoadState = .idle
    @Published var activeFilters: Set<RepoOwnershipKind> = Set(RepoOwnershipKind.allCases)
    @Published var searchQuery = ""

    var selectedCount: Int { selectedIDs.count }
    var shouldWarn: Bool { RepoPicker.shouldWarnSelection(currentCount: selectedCount) }

    var filteredRepos: [GitHubRepository] {
        guard let login = selfLogin else { return [] }
        return RepoPicker.filter(
            repos: repos,
            activeFilters: activeFilters,
            searchQuery: searchQuery,
            selfLogin: login
        )
    }

    var monitoredRepos: [MonitoredRepo] {
        RepoPicker.monitoredRepos(from: repos, selectedIDs: selectedIDs)
    }

    private var selfLogin: String?
    private let fetchRepos: () async throws -> [GitHubRepository]
    private let storedSelection: () -> Set<Int>?
    private let persistSelection: (Set<Int>) -> Void

    init(
        selfLogin: String?,
        fetchRepos: @escaping () async throws -> [GitHubRepository],
        storedSelection: @escaping () -> Set<Int>? = { nil },
        persistSelection: @escaping (Set<Int>) -> Void = { _ in }
    ) {
        self.selfLogin = selfLogin
        self.fetchRepos = fetchRepos
        self.storedSelection = storedSelection
        self.persistSelection = persistSelection
    }

    func loadIfNeeded() async {
        guard loadState == .idle, selfLogin != nil else { return }
        loadState = .loading
        do {
            let fetched = try await fetchRepos()
            repos = fetched.sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
            applyInitialSelection()
            loadState = .loaded
        } catch {
            repos = []
            selectedIDs = []
            loadState = .failed("Could not load repositories.")
        }
    }

    func resetForSignOut() {
        repos = []
        selectedIDs = []
        loadState = .idle
        searchQuery = ""
        activeFilters = Set(RepoOwnershipKind.allCases)
        persistSelection([])
    }

    func updateSelfLogin(_ login: String?) async {
        guard login != selfLogin else {
            if loadState == .idle, login != nil {
                await loadIfNeeded()
            }
            return
        }
        resetForSignOut()
        selfLogin = login
        await loadIfNeeded()
    }

    func isSelected(_ repo: GitHubRepository) -> Bool {
        selectedIDs.contains(repo.id)
    }

    func canSelectMore() -> Bool {
        RepoPicker.canAddSelection(currentCount: selectedCount)
    }

    func setSelected(_ repo: GitHubRepository, enabled: Bool) {
        if enabled {
            guard canSelectMore() else { return }
            selectedIDs.insert(repo.id)
        } else {
            selectedIDs.remove(repo.id)
        }
        persistSelection(selectedIDs)
    }

    func toggleFilter(_ kind: RepoOwnershipKind) {
        if activeFilters.contains(kind) {
            activeFilters.remove(kind)
        } else {
            activeFilters.insert(kind)
        }
    }

    private func applyInitialSelection() {
        guard let login = selfLogin else {
            selectedIDs = []
            return
        }
        if let stored = storedSelection(), !stored.isEmpty {
            selectedIDs = stored.intersection(repos.map(\.id))
        } else {
            selectedIDs = RepoPicker.defaultSelectedIDs(from: repos, selfLogin: login)
            persistSelection(selectedIDs)
        }
    }
}

extension RepoSelectionController {
    /// Live controller backed by Keychain PAT + GitHub API.
    static func live(selfLogin: String?, patStore: PATStore = KeychainPATStore()) -> RepoSelectionController {
        RepoSelectionController(
            selfLogin: selfLogin,
            fetchRepos: {
                guard let token = try patStore.load(), !token.isEmpty else {
                    throw GitHubClientError.invalidToken
                }
                let client = GitHubClient(token: token)
                let result = try await client.fetchUserRepos()
                switch result {
                case .fresh(let repos, _, _):
                    return repos
                case .notModified:
                    throw GitHubClientError.unexpectedResponse
                }
            },
            storedSelection: {
                guard let ids = UserDefaults.standard.array(forKey: Self.selectionDefaultsKey) as? [Int] else {
                    return nil
                }
                return Set(ids)
            },
            persistSelection: { ids in
                UserDefaults.standard.set(Array(ids), forKey: Self.selectionDefaultsKey)
            }
        )
    }

    private static let selectionDefaultsKey = "com.lucasandrade.GitHubLiveNotifications.selectedRepoIDs"
}
