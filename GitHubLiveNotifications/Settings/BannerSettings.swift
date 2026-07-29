import Foundation
import GHNCore

/// Synthetic inbox sources that have independent banner toggles (PLAN.md).
enum BannerCategory: String, CaseIterable, Codable, Equatable {
    case newOnMyRepos = "new_on_my_repos"
    case stars
}

/// Global + per-category banner delivery preferences (PLAN.md; UI-SPEC §4).
struct BannerSettings: Equatable, Codable {
    var globalEnabled: Bool
    var perCategory: [String: Bool]

    /// Factory defaults: high-signal ON; noisy reasons + Stars OFF (PLAN.md).
    static func factoryDefaults() -> BannerSettings {
        var perCategory: [String: Bool] = [:]
        for reason in NotificationReason.allCases {
            perCategory[reason.rawValue] = reason.bannerEnabledByDefault
        }
        perCategory[BannerCategory.newOnMyRepos.rawValue] = true
        perCategory[BannerCategory.stars.rawValue] = false
        return BannerSettings(globalEnabled: true, perCategory: perCategory)
    }

    func isBannerEnabled(for categoryID: String) -> Bool {
        guard globalEnabled else { return false }
        return perCategory[categoryID, default: false]
    }

    mutating func setBannerEnabled(_ enabled: Bool, for categoryID: String) {
        perCategory[categoryID] = enabled
    }
}

private extension NotificationReason {
    /// PLAN.md: `comment`/`state_change`/`manual`/`subscribed`/`ci_activity` OFF; high-signal ON.
    var bannerEnabledByDefault: Bool {
        switch self {
        case .comment, .stateChange, .manual, .subscribed, .ciActivity:
            return false
        case .assign, .author, .mention, .reviewRequested, .teamMention, .securityAlert:
            return true
        }
    }
}

/// Observable store for banner preferences; persists to UserDefaults.
@MainActor
final class BannerSettingsStore: ObservableObject {
    @Published private(set) var settings: BannerSettings

    private let defaults: UserDefaults
    private static let storageKey = "bannerSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(BannerSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .factoryDefaults()
        }
    }

    var globalEnabled: Bool {
        get { settings.globalEnabled }
        set {
            settings.globalEnabled = newValue
            objectWillChange.send()
            persist()
        }
    }

    func isBannerEnabled(for categoryID: String) -> Bool {
        settings.isBannerEnabled(for: categoryID)
    }

    func setBannerEnabled(_ enabled: Bool, for categoryID: String) {
        settings.setBannerEnabled(enabled, for: categoryID)
        objectWillChange.send()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
