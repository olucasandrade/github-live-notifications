import XCTest

/// Acceptance tests for T3.4 CI macos-14 + xcodebuild wiring.
final class CIConfigTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testCIWorkflowRunsOnMacOS14() throws {
        let workflow = try String(
            contentsOf: repoRoot.appendingPathComponent(".github/workflows/ci.yml"),
            encoding: .utf8
        )
        XCTAssertTrue(
            workflow.contains("runs-on: macos-14"),
            "CI must run on macos-14 so xcodebuild uses a real Xcode.app"
        )
    }

    func testCIWorkflowSelectsXcode154() throws {
        let workflow = try String(
            contentsOf: repoRoot.appendingPathComponent(".github/workflows/ci.yml"),
            encoding: .utf8
        )
        XCTAssertTrue(
            workflow.contains("Xcode_15.4.app"),
            "CI must pin Xcode 15.4 before running scripts/check.sh"
        )
    }

    func testAgentsDocumentsXcodeVersionPin() throws {
        let agents = try String(
            contentsOf: repoRoot.appendingPathComponent("AGENTS.md"),
            encoding: .utf8
        )
        XCTAssertTrue(
            agents.contains("Xcode 15.4"),
            "AGENTS.md must document the CI Xcode version pin"
        )
    }

    func testXcodeCheckScriptRequiresXcodebuildInCI() throws {
        let script = try String(
            contentsOf: repoRoot.appendingPathComponent("scripts/xcode-check.sh"),
            encoding: .utf8
        )
        XCTAssertTrue(
            script.contains("GITHUB_ACTIONS"),
            "xcode-check.sh must fail in CI when xcodebuild is unavailable"
        )
    }
}
