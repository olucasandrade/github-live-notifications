import GHNCore
import XCTest
@testable import GitHubLiveNotifications

/// Acceptance tests for T3.3 first-launch PAT sheet (UI-SPEC §3.2).
@MainActor
final class PATSetupTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    // MARK: - UI-SPEC §3.2 structure

    func testPATSetupSheetUsesSecureFieldAndScopesCallout() throws {
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("GitHubLiveNotifications/PATSetupSheet.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("SecureField"), "PAT entry must use SecureField")
        XCTAssertTrue(source.contains(".rounded"), "Brand wordmark must use SF Rounded")
        XCTAssertTrue(source.contains("notifications"), "Scopes callout must list notifications")
        XCTAssertTrue(source.contains("repo"), "Scopes callout must list repo")
        XCTAssertTrue(source.contains("read:user"), "Scopes callout must list read:user")
        XCTAssertTrue(
            source.contains("Create a classic token"),
            "Must link to GitHub classic token docs"
        )
    }

    func testDesignTokensUseSignalGreenNotPurple() throws {
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("GitHubLiveNotifications/DesignTokens.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("1A7F37"), "Light accent must be signal green #1A7F37")
        XCTAssertTrue(source.contains("3FB950"), "Dark accent must be signal green #3FB950")
        XCTAssertFalse(source.contains("purple"), "Purple accents are banned by UI-SPEC")
    }

    // MARK: - Validation behavior

    func testValidateTokenSucceedsAndExposesLogin() async throws {
        let store = InMemoryPATStore()
        let controller = AuthController(
            patStore: store,
            validateToken: { token in
                XCTAssertEqual(token, "ghp_valid")
                return GitHubUser(login: "octocat", id: 1)
            }
        )

        await controller.validateAndSave(token: "ghp_valid")

        XCTAssertEqual(controller.login, "octocat")
        XCTAssertTrue(controller.isAuthenticated)
        XCTAssertEqual(try store.load(), "ghp_valid")
    }

    func testValidateTokenSurfacesInvalidTokenError() async {
        let controller = AuthController(
            patStore: InMemoryPATStore(),
            validateToken: { _ in throw GitHubClientError.invalidToken }
        )

        await controller.validateAndSave(token: "ghp_bad")

        XCTAssertNil(controller.login)
        XCTAssertFalse(controller.isAuthenticated)
        if case .failed(let message) = controller.validationState {
            XCTAssertTrue(message.localizedCaseInsensitiveContains("invalid"))
        } else {
            XCTFail("expected .failed validation state, got \(controller.validationState)")
        }
    }
}

/// Test double for `PATStore` — never touches Keychain.
private final class InMemoryPATStore: PATStore {
    private var token: String?

    func save(_ token: String) throws { self.token = token }
    func load() throws -> String? { token }
    func delete() throws { token = nil }
}
