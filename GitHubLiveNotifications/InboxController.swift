import AppKit
import Foundation
import GHNCore

/// Inbox state, unread badge, mark-read actions, and browser URL opening (T4.4).
@MainActor
final class InboxController: ObservableObject {
    @Published private(set) var items: [InboxItem] = []

    var unreadCount: Int {
        actions?.unreadItems(in: items).count ?? items.count
    }

    private var actions: InboxActions?
    private var urlResolver: ThreadHTMLURLResolver?

    func configure(token: String?) {
        guard let token, !token.isEmpty else {
            actions = nil
            urlResolver = nil
            return
        }
        let client = GitHubClient(token: token)
        let cache = UserDefaultsCacheStore(defaults: .standard)
        actions = InboxActions(client: client, cache: cache)
        urlResolver = ThreadHTMLURLResolver(client: client)
    }

    func replaceItems(_ newItems: [InboxItem]) {
        items = newItems
    }

    func isUnread(_ item: InboxItem) -> Bool {
        actions?.isUnread(item) ?? true
    }

    func markRead(_ item: InboxItem) {
        guard let actions else { return }
        Task {
            try? await actions.markRead(item)
            await MainActor.run { objectWillChange.send() }
        }
    }

    func markAllRead() {
        guard let actions else { return }
        Task {
            try? await actions.markAllRead(in: items)
            await MainActor.run { objectWillChange.send() }
        }
    }

    func openInBrowser(_ item: InboxItem) {
        Task {
            guard let url = await resolvedURL(for: item) else { return }
            NSWorkspace.shared.open(url)
        }
    }

    private func resolvedURL(for item: InboxItem) async -> URL? {
        switch item.source {
        case .synthetic:
            return item.url
        case .thread:
            if let url = item.url, url.host?.lowercased() == "github.com" {
                return url
            }
            guard let thread = InboxItemThreadBridge.notificationThread(from: item),
                  let resolver = urlResolver else {
                return item.url
            }
            return await resolver.resolve(thread: thread)
        }
    }
}
