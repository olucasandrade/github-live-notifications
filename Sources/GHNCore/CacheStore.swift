import Foundation

/// Persistent cache for dedup and baseline state (PLAN.md: Cache).
///
/// - Thread IDs: seen notification threads, FIFO-capped at 1000.
/// - PR/issue item IDs: seen items per repo, FIFO-capped at 200 per repo.
/// - Star counts: last known stargazer count per repo (delta detection).
/// - ETags: per request key, for conditional GETs / 304 handling.
///
/// Per-repo state (item IDs, star count) is wiped when a repo is unselected;
/// everything is wiped on sign-out.
public protocol CacheStore: AnyObject {
    /// All recorded thread IDs, oldest first.
    var threadIDs: [String] { get }
    /// Records thread IDs as seen; deduplicates and FIFO-evicts the oldest beyond the cap.
    func recordThreadIDs(_ ids: [String])

    /// Seen PR/issue item IDs for a repo.
    func itemIDs(forRepo repo: MonitoredRepo) -> Set<String>
    /// Records item IDs as seen for a repo; deduplicates and FIFO-evicts the oldest beyond the cap.
    func recordItemIDs(_ ids: [String], forRepo repo: MonitoredRepo)

    /// Last recorded star count for a repo, or nil if never recorded.
    func starCount(forRepo repo: MonitoredRepo) -> Int?
    func recordStarCount(_ count: Int, forRepo repo: MonitoredRepo)

    /// ETag for a request key (e.g. "notifications", "stars:owner/name"), or nil.
    func etag(forKey key: String) -> String?
    /// Records (or clears, when nil) the ETag for a request key.
    func recordETag(_ etag: String?, forKey key: String)

    /// Whether notification threads have completed a silent baseline fetch.
    var threadsBaselined: Bool { get }
    func markThreadsBaselined()

    /// Whether PR/issue IDs for a repo have completed a silent baseline fetch.
    func itemsBaselined(forRepo repo: MonitoredRepo) -> Bool
    func markItemsBaselined(forRepo repo: MonitoredRepo)

    /// Wipes all per-repo state (item IDs, star count) — repo unselected.
    func wipeRepo(_ repo: MonitoredRepo)
    /// Wipes the entire cache — sign-out.
    func wipeAll()

    /// Thread IDs marked read locally after PATCH or mark-all (T2.4).
    func isThreadRead(_ id: String) -> Bool
    func markThreadRead(_ id: String)
    func markAllThreadsRead(_ ids: [String])

    /// Synthetic inbox item IDs dismissed locally (T2.4).
    func isSyntheticDismissed(_ id: String) -> Bool
    func dismissSynthetic(_ id: String)
    func dismissAllSynthetics(_ ids: [String])
}

/// UserDefaults-backed `CacheStore`. All keys live under the `cache.` prefix.
public final class UserDefaultsCacheStore: CacheStore {
    /// FIFO cap for thread IDs (PLAN.md: 1k thread IDs FIFO).
    public static let maxThreadIDs = 1000
    /// FIFO cap for PR/issue item IDs per repo (PLAN.md: 200 IDs/repo).
    public static let maxItemIDsPerRepo = 200

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: Keys

    private enum Key {
        static let prefix = "cache."
        static let threadIDs = prefix + "threadIDs"
        static let threadsBaselined = prefix + "threadsBaselined"
        static func itemIDs(_ repo: MonitoredRepo) -> String { prefix + "itemIDs." + repo.fullName }
        static func itemsBaselined(_ repo: MonitoredRepo) -> String { prefix + "itemsBaselined." + repo.fullName }
        static func starCount(_ repo: MonitoredRepo) -> String { prefix + "starCount." + repo.fullName }
        static func etag(_ key: String) -> String { prefix + "etag." + key }
        static let readThreadIDs = prefix + "readThreadIDs"
        static let dismissedSyntheticIDs = prefix + "dismissedSyntheticIDs"
    }

    // MARK: Thread IDs

    public var threadIDs: [String] {
        defaults.stringArray(forKey: Key.threadIDs) ?? []
    }

    public func recordThreadIDs(_ ids: [String]) {
        defaults.set(Self.appending(ids, to: threadIDs, cap: Self.maxThreadIDs), forKey: Key.threadIDs)
    }

    // MARK: PR/issue item IDs

    public func itemIDs(forRepo repo: MonitoredRepo) -> Set<String> {
        Set(defaults.stringArray(forKey: Key.itemIDs(repo)) ?? [])
    }

    public func recordItemIDs(_ ids: [String], forRepo repo: MonitoredRepo) {
        let key = Key.itemIDs(repo)
        let existing = defaults.stringArray(forKey: key) ?? []
        defaults.set(Self.appending(ids, to: existing, cap: Self.maxItemIDsPerRepo), forKey: key)
    }

    // MARK: Star counts

    public func starCount(forRepo repo: MonitoredRepo) -> Int? {
        defaults.object(forKey: Key.starCount(repo)) as? Int
    }

    public func recordStarCount(_ count: Int, forRepo repo: MonitoredRepo) {
        defaults.set(count, forKey: Key.starCount(repo))
    }

    // MARK: ETags

    public func etag(forKey key: String) -> String? {
        defaults.string(forKey: Key.etag(key))
    }

    public func recordETag(_ etag: String?, forKey key: String) {
        defaults.set(etag, forKey: Key.etag(key))
    }

    // MARK: Baseline flags

    public var threadsBaselined: Bool {
        defaults.bool(forKey: Key.threadsBaselined)
    }

    public func markThreadsBaselined() {
        defaults.set(true, forKey: Key.threadsBaselined)
    }

    public func itemsBaselined(forRepo repo: MonitoredRepo) -> Bool {
        defaults.bool(forKey: Key.itemsBaselined(repo))
    }

    public func markItemsBaselined(forRepo repo: MonitoredRepo) {
        defaults.set(true, forKey: Key.itemsBaselined(repo))
    }

    // MARK: Read / dismissed state (T2.4)

    public func isThreadRead(_ id: String) -> Bool {
        readThreadIDSet.contains(id)
    }

    public func markThreadRead(_ id: String) {
        var ids = readThreadIDs
        if !ids.contains(id) {
            ids.append(id)
            defaults.set(ids, forKey: Key.readThreadIDs)
        }
    }

    public func markAllThreadsRead(_ ids: [String]) {
        var existing = readThreadIDs
        var seen = Set(existing)
        for id in ids where seen.insert(id).inserted {
            existing.append(id)
        }
        defaults.set(existing, forKey: Key.readThreadIDs)
    }

    public func isSyntheticDismissed(_ id: String) -> Bool {
        dismissedSyntheticIDSet.contains(id)
    }

    public func dismissSynthetic(_ id: String) {
        var ids = dismissedSyntheticIDs
        if !ids.contains(id) {
            ids.append(id)
            defaults.set(ids, forKey: Key.dismissedSyntheticIDs)
        }
    }

    public func dismissAllSynthetics(_ ids: [String]) {
        var existing = dismissedSyntheticIDs
        var seen = Set(existing)
        for id in ids where seen.insert(id).inserted {
            existing.append(id)
        }
        defaults.set(existing, forKey: Key.dismissedSyntheticIDs)
    }

    private var readThreadIDs: [String] {
        defaults.stringArray(forKey: Key.readThreadIDs) ?? []
    }

    private var readThreadIDSet: Set<String> {
        Set(readThreadIDs)
    }

    private var dismissedSyntheticIDs: [String] {
        defaults.stringArray(forKey: Key.dismissedSyntheticIDs) ?? []
    }

    private var dismissedSyntheticIDSet: Set<String> {
        Set(dismissedSyntheticIDs)
    }

    // MARK: Wipe

    public func wipeRepo(_ repo: MonitoredRepo) {
        defaults.removeObject(forKey: Key.itemIDs(repo))
        defaults.removeObject(forKey: Key.starCount(repo))
        defaults.removeObject(forKey: Key.itemsBaselined(repo))
    }

    public func wipeAll() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Key.prefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: FIFO helpers

    /// Appends new (not-yet-seen) IDs to `existing`, then drops the oldest so the
    /// result is at most `cap` entries.
    private static func appending(_ new: [String], to existing: [String], cap: Int) -> [String] {
        var seen = Set(existing)
        var result = existing
        for id in new where seen.insert(id).inserted {
            result.append(id)
        }
        if result.count > cap {
            result.removeFirst(result.count - cap)
        }
        return result
    }
}
