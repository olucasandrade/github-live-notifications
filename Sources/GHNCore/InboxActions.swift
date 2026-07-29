import Foundation

/// Mark-read and dismiss actions (PLAN.md: T2.4).
///
/// Thread items call the GitHub notifications API; synthetic items (stars,
/// new-on-repos) are dismissed locally in the cache. Mark-all does both.
public struct InboxActions {
    public let client: GitHubClient
    public let cache: CacheStore

    public init(client: GitHubClient, cache: CacheStore) {
        self.client = client
        self.cache = cache
    }

    /// PATCH `/notifications/threads/{id}` and record local read state.
    public func markThreadRead(_ item: InboxItem) async throws {
        guard case .thread = item.source else {
            dismissSynthetic(item)
            return
        }
        try await client.markThreadRead(threadID: item.id)
        cache.markThreadRead(item.id)
    }

    /// Local dismiss for synthetic inbox items (stars, new-on-repos).
    public func dismissSynthetic(_ item: InboxItem) {
        cache.dismissSynthetic(item.id)
    }

    /// Routes by source: threads → API, synthetics → local dismiss.
    public func markRead(_ item: InboxItem) async throws {
        switch item.source {
        case .thread:
            try await markThreadRead(item)
        case .synthetic:
            dismissSynthetic(item)
        }
    }

    /// PUT `/notifications` for threads plus local dismiss for all synthetics.
    public func markAllRead(in items: [InboxItem]) async throws {
        let threadIDs = items.compactMap { item -> String? in
            guard case .thread = item.source else { return nil }
            return item.id
        }
        let syntheticIDs = items.compactMap { item -> String? in
            guard case .synthetic = item.source else { return nil }
            return item.id
        }

        if !threadIDs.isEmpty {
            try await client.markAllNotificationsRead()
            cache.markAllThreadsRead(threadIDs)
        }
        if !syntheticIDs.isEmpty {
            cache.dismissAllSynthetics(syntheticIDs)
        }
    }

    public func isUnread(_ item: InboxItem) -> Bool {
        switch item.source {
        case .thread:
            return !cache.isThreadRead(item.id)
        case .synthetic:
            return !cache.isSyntheticDismissed(item.id)
        }
    }

    public func unreadItems(in items: [InboxItem]) -> [InboxItem] {
        items.filter(isUnread)
    }
}
