import Foundation
import GHNCore

/// Validates and persists the GitHub classic PAT (UI-SPEC §3.2; PLAN.md Auth).
@MainActor
final class AuthController: ObservableObject {
    enum ValidationState: Equatable {
        case idle
        case validating
        case failed(String)
    }

    @Published private(set) var login: String?
    @Published var validationState: ValidationState = .idle

    var isAuthenticated: Bool { login != nil }

    private let patStore: PATStore
    private let validateToken: (String) async throws -> GitHubUser

    init(
        patStore: PATStore = KeychainPATStore(),
        validateToken: @escaping (String) async throws -> GitHubUser = AuthController.liveValidate
    ) {
        self.patStore = patStore
        self.validateToken = validateToken
    }

    /// Restores session from Keychain on launch when a PAT is already stored.
    func restoreSessionIfNeeded() async {
        guard login == nil else { return }
        let stored: String?
        do {
            stored = try patStore.load()
        } catch {
            return
        }
        guard let token = stored, !token.isEmpty else { return }
        await validateAndSave(token: token, persist: false)
    }

    /// Validates via `GET /user`, saves to Keychain on success, and exposes `login`.
    func validateAndSave(token: String, persist: Bool = true) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        validationState = .validating
        do {
            let user = try await validateToken(trimmed)
            if persist {
                try patStore.save(trimmed)
            }
            login = user.login
            validationState = .idle
        } catch GitHubClientError.invalidToken {
            login = nil
            validationState = .failed("Invalid token. Check scopes and try again.")
        } catch {
            login = nil
            validationState = .failed("Could not reach GitHub. Try again.")
        }
    }

    private static func liveValidate(_ token: String) async throws -> GitHubUser {
        let client = GitHubClient(token: token)
        let result = try await client.fetchUser()
        switch result {
        case .fresh(let user, _, _):
            return user
        case .notModified:
            throw GitHubClientError.unexpectedResponse
        }
    }
}
