import XCTest
@testable import GHNCore

final class DebugExportTests: XCTestCase {
    func testRedactSecretsRemovesClassicPAT() {
        let input = "Authorization: Bearer ghp_abcdefghijklmnopqrstuvwxyz1234567890"
        let output = DebugExport.redactSecrets(in: input)
        XCTAssertFalse(output.contains("ghp_abcdefghijklmnopqrstuvwxyz1234567890"))
        XCTAssertTrue(output.contains("[REDACTED]"))
    }

    func testRedactSecretsRemovesOAuthToken() {
        let input = "token=gho_abcdefghijklmnopqrstuvwxyz1234567890"
        let output = DebugExport.redactSecrets(in: input)
        XCTAssertFalse(output.contains("gho_abcdefghijklmnopqrstuvwxyz1234567890"))
        XCTAssertTrue(output.contains("[REDACTED]"))
    }

    func testRedactSecretsRemovesFineGrainedPAT() {
        let input = "saved github_pat_11AAAAAAbbbbBBBBccccCCCCddddDDDDeeeeEEEEffffFFFF"
        let output = DebugExport.redactSecrets(in: input)
        XCTAssertFalse(output.contains("github_pat_11AAAAAA"))
        XCTAssertTrue(output.contains("[REDACTED]"))
    }

    func testRedactSecretsLeavesUnrelatedTextUntouched() {
        let input = "poll ok login=olucasandrade status=200"
        XCTAssertEqual(DebugExport.redactSecrets(in: input), input)
    }

    func testDebugLogExportAppliesRedaction() {
        let log = DebugLog()
        log.append("Bearer ghp_secretTokenValue123456789012345678901234")
        log.append("done")

        let exported = log.exportRedacted()
        XCTAssertFalse(exported.contains("ghp_secretTokenValue"))
        XCTAssertTrue(exported.contains("[REDACTED]"))
        XCTAssertTrue(exported.contains("done"))
    }
}
