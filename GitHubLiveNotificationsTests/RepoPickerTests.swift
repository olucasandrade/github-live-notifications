import XCTest

/// Source acceptance tests for T5.2 repo picker UI (UI-SPEC §3.1).
final class RepoPickerTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func appSource(at path: String) throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("GitHubLiveNotifications/\(path)"),
            encoding: .utf8
        )
    }

    func testSettingsRepositoriesSectionUsesRepoPickerView() throws {
        let settings = try appSource(at: "Settings/SettingsView.swift")
        XCTAssertTrue(settings.contains("RepoPickerView"), "Repositories group must embed RepoPickerView")
    }

    func testRepoPickerViewIncludesSearchAndFilters() throws {
        let source = try appSource(at: "Settings/RepoPickerView.swift")
        XCTAssertTrue(source.contains("TextField"), "Repo picker must include search field")
        for filter in ["Owned", "Collaborator", "Org"] {
            XCTAssertTrue(source.contains(filter), "Repo picker must expose \"\(filter)\" filter")
        }
    }

    func testRepoPickerViewEnforcesCapAndWarning() throws {
        let source = try appSource(at: "Settings/RepoPickerView.swift")
        XCTAssertTrue(source.contains("RepoPickerLimits.maxSelected"), "Repo picker must enforce hard cap")
        XCTAssertTrue(source.contains("RepoPickerLimits.warnThreshold"), "Repo picker must warn at 40+")
        XCTAssertTrue(source.contains("shouldWarnSelection"), "Repo picker must show inline warning")
    }

    func testRepoPickerViewUsesSteppersForSelection() throws {
        let source = try appSource(at: "Settings/RepoPickerView.swift")
        XCTAssertTrue(
            source.contains("Stepper") || source.contains("toggleSelection"),
            "Repo picker must use steppers or equivalent per-row selection controls"
        )
    }
}
