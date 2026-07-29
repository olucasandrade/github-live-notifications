import Foundation
import Security

public enum PATStoreError: Error, Equatable {
    case unexpectedStatus(OSStatus)
}

/// Persists the GitHub classic PAT in the macOS Keychain (PLAN.md: Auth).
///
/// Tokens are never logged. Callers must not log values returned from `load()`.
public protocol PATStore: AnyObject {
    /// Stores `token`, replacing any existing value.
    func save(_ token: String) throws
    /// Returns the stored token, or nil when none is saved.
    func load() throws -> String?
    /// Removes the stored token. Succeeds when already absent.
    func delete() throws
}

/// Keychain-backed `PATStore` using service
/// `com.lucasandrade.GitHubLiveNotifications.pat` and `WhenUnlocked` accessibility.
public final class KeychainPATStore: PATStore {
    public static let service = "com.lucasandrade.GitHubLiveNotifications.pat"

    private let service: String
    private let account: String

    public init(
        service: String = KeychainPATStore.service,
        account: String = "pat"
    ) {
        self.service = service
        self.account = account
    }

    public func save(_ token: String) throws {
        try delete()
        let status = SecItemAdd(Self.saveAttributes(
            token: token,
            service: service,
            account: account
        ) as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PATStoreError.unexpectedStatus(status)
        }
    }

    public func load() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw PATStoreError.unexpectedStatus(status)
        }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw PATStoreError.unexpectedStatus(status)
        }
    }

    // MARK: - Query builders (test-visible)

    static func saveAttributes(token: String, service: String, account: String) -> [String: Any] {
        var query = baseQuery(service: service, account: account)
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        return query
    }

    private func baseQuery() -> [String: Any] {
        Self.baseQuery(service: service, account: account)
    }

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
