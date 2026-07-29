import Foundation
import GHNCore

/// Builds a `NotificationThread` from an inbox row so core URL resolution can run in the app layer.
enum InboxItemThreadBridge {
    static func notificationThread(from item: InboxItem) -> NotificationThread? {
        guard case .thread(let reason) = item.source else { return nil }

        let payload: [String: Any] = [
            "id": item.id,
            "reason": reason.rawValue,
            "subject": [
                "title": item.title,
                "url": item.url?.absoluteString ?? "",
                "type": "Issue",
            ],
            "repository": ["full_name": item.repoFullName],
            "updated_at": iso8601String(from: item.updatedAt),
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload) else {
            return nil
        }
        return try? Self.decoder.decode(NotificationThread.self, from: data)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
