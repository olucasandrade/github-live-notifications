import Foundation

/// Baseline vs diff engine (PLAN.md: T2.2).
///
/// The first successful fetch per source is a silent baseline — nothing is
/// emitted and the cache is seeded. Later polls emit only unseen notification
/// threads, new PR/issue IDs, and positive star-count deltas. Star decreases
/// update the cache silently (no unstar banners).
public struct DiffEngine {
    public let cache: CacheStore

    public init(cache: CacheStore) {
        self.cache = cache
    }

    /// Diffs notification threads against the thread-ID cache.
    public func diffThreads(_ threads: [InboxItem]) -> [InboxItem] {
        let ids = threads.map(\.id)
        if !cache.threadsBaselined {
            cache.recordThreadIDs(ids)
            cache.markThreadsBaselined()
            return []
        }

        let seen = Set(cache.threadIDs)
        let newItems = threads.filter { !seen.contains($0.id) }
        if !newItems.isEmpty {
            cache.recordThreadIDs(newItems.map(\.id))
        }
        return newItems
    }

    /// Diffs PR/issue inbox items for a repo against the per-repo item-ID cache.
    public func diffRepoItems(_ items: [InboxItem], forRepo repo: MonitoredRepo) -> [InboxItem] {
        let ids = items.map(\.id)
        if !cache.itemsBaselined(forRepo: repo) {
            cache.recordItemIDs(ids, forRepo: repo)
            cache.markItemsBaselined(forRepo: repo)
            return []
        }

        let seen = cache.itemIDs(forRepo: repo)
        let newItems = items.filter { !seen.contains($0.id) }
        if !newItems.isEmpty {
            cache.recordItemIDs(newItems.map(\.id), forRepo: repo)
        }
        return newItems
    }

    /// Diffs a repo's star count. Returns a synthetic stars item only for a
    /// positive delta after baseline; decreases and unchanged counts are silent.
    public func diffStarCount(_ count: Int, forRepo repo: MonitoredRepo, now: Date) -> InboxItem? {
        guard let previous = cache.starCount(forRepo: repo) else {
            cache.recordStarCount(count, forRepo: repo)
            return nil
        }

        cache.recordStarCount(count, forRepo: repo)
        let delta = count - previous
        guard delta > 0 else { return nil }

        return InboxItem(
            id: "stars:\(repo.fullName):\(count)",
            title: "\(repo.fullName): +\(delta) stars",
            repoFullName: repo.fullName,
            url: URL(string: "https://github.com/\(repo.fullName)/stargazers"),
            source: .synthetic(.stars),
            updatedAt: now
        )
    }
}
