import Foundation

/// Redacts GitHub credential prefixes from debug export text (PLAN.md: Privacy).
public enum DebugExport {
    private static let tokenPattern = #"(ghp_|gho_|github_pat_)[A-Za-z0-9_]+"#

    /// Returns `text` with classic PAT, OAuth, and fine-grained token values replaced by `[REDACTED]`.
    public static func redactSecrets(in text: String) -> String {
        text.replacingOccurrences(
            of: tokenPattern,
            with: "[REDACTED]",
            options: .regularExpression
        )
    }
}

/// In-memory debug log buffer; export always applies `DebugExport.redactSecrets`.
public final class DebugLog: @unchecked Sendable {
    public static let shared = DebugLog()

    private var lines: [String] = []
    private let lock = NSLock()

    public init() {}

    public func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        lines.append(line)
    }

    public func exportRedacted() -> String {
        lock.lock()
        let snapshot = lines.joined(separator: "\n")
        lock.unlock()
        return DebugExport.redactSecrets(in: snapshot)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        lines.removeAll(keepingCapacity: false)
    }
}
