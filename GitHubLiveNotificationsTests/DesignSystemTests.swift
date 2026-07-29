import XCTest

/// Acceptance tests for T4.1 design tokens + double-bezel containers (UI-SPEC §1).
final class DesignSystemTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func appSource(named name: String) throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("GitHubLiveNotifications/\(name)"),
            encoding: .utf8
        )
    }

    private func assetCatalogPath(_ colorName: String) -> URL {
        repoRoot
            .appendingPathComponent("GitHubLiveNotifications/Assets.xcassets")
            .appendingPathComponent("\(colorName).colorset/Contents.json")
    }

    // MARK: - Radius tokens (UI-SPEC §1.3)

    func testDesignTokensDefineUISpecCornerRadii() throws {
        let source = try appSource(named: "Design/DesignTokens.swift")
        XCTAssertTrue(source.contains("panelOuter"), "Missing panel outer radius token")
        XCTAssertTrue(source.contains("14"), "Panel outer radius must be 14")
        XCTAssertTrue(source.contains("innerGroup"), "Missing inner group radius token")
        XCTAssertTrue(source.contains("10"), "Inner group radius must be 10")
        XCTAssertTrue(source.contains("pill"), "Missing pill radius token")
        XCTAssertTrue(source.contains("6"), "Pill radius must be 6")
        XCTAssertTrue(source.contains("iconWell"), "Missing icon well radius token")
        XCTAssertTrue(source.contains("7"), "Icon well radius must be 7")
    }

    // MARK: - Typography tokens (UI-SPEC §1.2)

    func testDesignTokensDefineUISpecTypography() throws {
        let source = try appSource(named: "Design/DesignTokens.swift")
        XCTAssertTrue(source.contains("rounded"), "Brand font must use SF Pro Rounded")
        XCTAssertTrue(source.contains("22"), "Brand font size must be 22")
        XCTAssertTrue(source.contains("semibold"), "Brand font weight must be semibold")
        XCTAssertTrue(source.contains("monospaced"), "Counts/timestamps must use SF Mono")
        XCTAssertTrue(source.contains("11"), "Meta and mono fonts use 11pt")
        XCTAssertTrue(source.contains("13"), "Panel/row titles use 13pt")
        XCTAssertTrue(source.contains("15"), "Empty-state headline uses 15pt")
    }

    // MARK: - Color tokens (UI-SPEC §1.1)

    func testColorAssetCatalogIncludesAccentSignalWithLightAndDark() throws {
        let url = assetCatalogPath("accent.signal")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "accent.signal colorset required")

        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let colors = try XCTUnwrap(json?["colors"] as? [[String: Any]])
        XCTAssertEqual(colors.count, 2, "accent.signal must define light + dark appearances")

        let light = colors[0]
        XCTAssertNil(
            (light["appearances"] as? [[String: Any]])?.first,
            "First entry must be the light (default) appearance"
        )

        let darkAppearances = try XCTUnwrap(colors[1]["appearances"] as? [[String: Any]])
        XCTAssertEqual(darkAppearances.first?["value"] as? String, "dark")

        let lightComponents = try colorComponents(from: colors[0])
        let darkComponents = try colorComponents(from: colors[1])
        XCTAssertEqual(lightComponents.red, 26, accuracy: 1, "Light accent must be #1A7F37")
        XCTAssertEqual(lightComponents.green, 127, accuracy: 1)
        XCTAssertEqual(lightComponents.blue, 55, accuracy: 1)
        XCTAssertEqual(darkComponents.red, 63, accuracy: 1, "Dark accent must be #3FB950")
        XCTAssertEqual(darkComponents.green, 185, accuracy: 1)
        XCTAssertEqual(darkComponents.blue, 80, accuracy: 1)
    }

    func testColorAssetCatalogIncludesSurfaceHairlineWithLightAndDark() throws {
        let url = assetCatalogPath("surface.hairline")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let colors = try XCTUnwrap(json?["colors"] as? [[String: Any]])
        XCTAssertEqual(colors.count, 2, "surface.hairline must define light + dark appearances")
    }

    func testDesignTokensExposeSemanticColorAccessors() throws {
        let source = try appSource(named: "Design/DesignTokens.swift")
        for token in [
            "surfaceCanvas",
            "surfaceElevated",
            "surfaceHairline",
            "textPrimary",
            "textSecondary",
            "textTertiary",
            "accentSignal",
            "stateDanger",
            "stateWarn",
        ] {
            XCTAssertTrue(source.contains(token), "Missing color accessor \(token)")
        }
    }

    // MARK: - Double-bezel container (UI-SPEC §1.3)

    func testDoubleBezelContainerMatchesUISpec() throws {
        let source = try appSource(named: "Components/DoubleBezel.swift")
        XCTAssertTrue(source.contains("struct DoubleBezel"), "Reusable DoubleBezel container required")
        XCTAssertTrue(source.contains("1.5"), "Outer bezel pad must be 1.5pt")
        XCTAssertTrue(source.contains("regularMaterial"), "Panel inner must use regularMaterial")
        XCTAssertTrue(source.contains("ultraThinMaterial"), "Header strip inner must use ultraThinMaterial")
        XCTAssertTrue(source.contains("surfaceHairline"), "Outer ring must use hairline token")
        XCTAssertTrue(source.contains("surfaceElevated"), "Outer fill must use elevated surface token")
    }

    func testMenuPanelUsesDoubleBezel() throws {
        let source = try appSource(named: "Panel/MenuPanelView.swift")
        XCTAssertTrue(source.contains("DoubleBezel"), "Menu panel must use DoubleBezel chrome")
    }

    // MARK: - Anti-slop (UI-SPEC §5)

    func testAppSourcesContainNoBannedDesignElements() throws {
        let appDir = repoRoot.appendingPathComponent("GitHubLiveNotifications")
        let swiftFiles = try FileManager.default.subpathsOfDirectory(atPath: appDir.path)
            .filter { $0.hasSuffix(".swift") }

        let bannedPatterns: [(String, String)] = [
            (#"(?i)purple|violet"#, "purple/violet accent"),
            (#"(?i)glow|shadow\s*\(\s*color:\s*\.(?:purple|blue|pink)"#, "neon glow"),
            ("", "emoji"),
        ]

        for file in swiftFiles {
            let contents = try String(
                contentsOf: appDir.appendingPathComponent(file),
                encoding: .utf8
            )
            for (pattern, label) in bannedPatterns {
                if label == "emoji" {
                    XCTAssertFalse(
                        contents.containsEmojiScalars,
                        "\(file) must not contain emoji"
                    )
                    continue
                }
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
                XCTAssertNil(
                    regex.firstMatch(in: contents, range: range),
                    "\(file) must not contain banned \(label)"
                )
            }
        }
    }

    // MARK: - Helpers

    private struct RGB8 {
        let red: Double
        let green: Double
        let blue: Double
    }

    private func colorComponents(from entry: [String: Any]) throws -> RGB8 {
        let color = try XCTUnwrap(entry["color"] as? [String: Any])
        let components = try XCTUnwrap(color["components"] as? [String: String])
        let red = Double(components["red"] ?? "") ?? 0
        let green = Double(components["green"] ?? "") ?? 0
        let blue = Double(components["blue"] ?? "") ?? 0
        return RGB8(red: red * 255, green: green * 255, blue: blue * 255)
    }
}

private extension String {
    var containsEmojiScalars: Bool {
        unicodeScalars.contains { scalar in
            scalar.properties.isEmoji && scalar.value > 0x238C
        }
    }
}
