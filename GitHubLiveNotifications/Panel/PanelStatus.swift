import Foundation

/// Header status line for the menu panel signal strip (UI-SPEC §2.1).
enum PanelStatus: Equatable {
    case fresh(lastUpdated: Date)
    case stale(lastUpdated: Date)
    case invalidToken
    case rateLimited(resumesAt: Date)

    /// Stale threshold from PLAN.md: no success in 20 min.
    static let staleThreshold: TimeInterval = 20 * 60

    static func from(lastSuccess: Date?, now: Date = Date()) -> PanelStatus {
        guard let lastSuccess else { return .invalidToken }
        let age = now.timeIntervalSince(lastSuccess)
        if age >= staleThreshold {
            return .stale(lastUpdated: lastSuccess)
        }
        return .fresh(lastUpdated: lastSuccess)
    }

    func statusCopy(relativeTo now: Date = Date()) -> String {
        switch self {
        case .fresh(let date):
            return "Updated \(Self.relativeTime(from: date, to: now)) ago"
        case .stale(let date):
            return "Stale · \(Self.relativeTime(from: date, to: now)) ago"
        case .invalidToken:
            return "Invalid token"
        case .rateLimited(let resumesAt):
            return "Rate limited · resumes \(Self.clockTime(resumesAt))"
        }
    }

    var usesDangerColor: Bool {
        switch self {
        case .invalidToken, .rateLimited:
            return true
        case .fresh, .stale:
            return false
        }
    }

    var usesWarnColor: Bool {
        if case .stale = self { return true }
        return false
    }

    // MARK: - Formatting

    private static func relativeTime(from date: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }

    private static func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
