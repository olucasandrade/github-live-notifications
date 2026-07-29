import GHNCore
import SwiftUI

/// Settings window with double-bezel Form groups (UI-SPEC §3.1).
struct SettingsView: View {
    @ObservedObject var auth: AuthController
    @Environment(\.openWindow) private var openWindow

    @State private var bannersEnabled = true
    @State private var includeBots = false
    @State private var includeDraftPRs = false
    @State private var launchAtLogin = false
    @State private var enabledReasons = Set(NotificationReason.allCases)
    @State private var bannerDelivery: [String: Bool] = [:]

    private static let releasesURL = URL(
        string: "https://github.com/olucasandrade/github-live-notifications/releases"
    )!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("GitHub Live Notifications")
                    .font(GHNFont.brand)
                    .foregroundStyle(GHNColor.textPrimary)

                Form {
                    SettingsGroup(title: "Account") {
                        accountSection
                    }

                    SettingsGroup(title: "Repositories") {
                        repositoriesSection
                    }

                    SettingsGroup(title: "Notification types") {
                        notificationTypesSection
                    }

                    SettingsGroup(title: "Banners") {
                        bannersSection
                    }

                    SettingsGroup(title: "Noise") {
                        noiseSection
                    }

                    SettingsGroup(title: "General") {
                        generalSection
                    }

                    SettingsGroup(title: "About") {
                        aboutSection
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
            .padding(20)
        }
        .frame(width: 520, height: 640)
        .background(GHNColor.surfaceCanvas)
    }

    // MARK: - Sections

    @ViewBuilder
    private var accountSection: some View {
        HStack(spacing: 12) {
            avatarInitials
            if let login = auth.login {
                Text("Signed in as **\(login)**")
                    .font(GHNFont.rowTitle)
            } else {
                Text("Not signed in")
                    .font(GHNFont.rowTitle)
                    .foregroundStyle(GHNColor.textSecondary)
            }
        }

        HStack(spacing: 12) {
            Button("Replace token…") {
                openWindow(id: "pat-setup")
            }
            .buttonStyle(.bordered)
            .tint(GHNColor.accentSignal)

            Button("Sign out", role: .destructive) {
                Task { await auth.signOut() }
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var avatarInitials: some View {
        let label = auth.login.map { String($0.prefix(1)).uppercased() } ?? "?"
        Text(label)
            .font(GHNFont.panelTitle)
            .foregroundStyle(GHNColor.accentSignal)
            .frame(width: 36, height: 36)
            .background(GHNColor.surfaceElevated, in: Circle())
            .overlay(Circle().strokeBorder(GHNColor.surfaceHairline, lineWidth: 1))
    }

    @ViewBuilder
    private var repositoriesSection: some View {
        Text("Search and filter repositories to monitor.")
            .font(GHNFont.meta)
            .foregroundStyle(GHNColor.textSecondary)
        Text("Up to 50 repositories · warning at 40+")
            .font(GHNFont.mono)
            .foregroundStyle(GHNColor.textTertiary)
    }

    @ViewBuilder
    private var notificationTypesSection: some View {
        ForEach(NotificationReason.allCases, id: \.self) { reason in
            reasonRow(id: reason.rawValue, title: reason.displayName) {
                Toggle("", isOn: reasonBinding(reason))
                    .labelsHidden()
            }
        }
        reasonRow(id: "new_on_my_repos", title: "New on my repos") {
            Toggle("", isOn: .constant(true))
                .labelsHidden()
        }
        reasonRow(id: "stars", title: "Stars") {
            Toggle("", isOn: .constant(false))
                .labelsHidden()
        }
    }

    @ViewBuilder
    private func reasonRow<Control: View>(
        id: String,
        title: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(GHNFont.rowTitle)
                Spacer()
                control()
            }
            Toggle("Deliver banner", isOn: bannerBinding(for: id))
                .font(GHNFont.meta)
                .disabled(!bannersEnabled)
                .padding(.leading, 8)
        }
    }

    @ViewBuilder
    private var bannersSection: some View {
        Toggle("Show banner notifications", isOn: $bannersEnabled)
            .font(GHNFont.rowTitle)
            .tint(GHNColor.accentSignal)
        Text("Alerts for enabled notification types when the app is in the background.")
            .font(GHNFont.meta)
            .foregroundStyle(GHNColor.textSecondary)
    }

    @ViewBuilder
    private var noiseSection: some View {
        Toggle("Include bots", isOn: $includeBots)
            .font(GHNFont.rowTitle)
        Toggle("Include draft PRs", isOn: $includeDraftPRs)
            .font(GHNFont.rowTitle)
    }

    @ViewBuilder
    private var generalSection: some View {
        Toggle("Launch at Login", isOn: $launchAtLogin)
            .font(GHNFont.rowTitle)
        Button("Export debug log…") {}
            .font(GHNFont.rowTitle)
    }

    @ViewBuilder
    private var aboutSection: some View {
        Text("Version 1.0.0-dev")
            .font(GHNFont.mono)
            .foregroundStyle(GHNColor.textSecondary)
        Link("GitHub Releases", destination: Self.releasesURL)
            .font(GHNFont.rowTitle)
            .tint(GHNColor.accentSignal)
    }

    // MARK: - Bindings

    private func reasonBinding(_ reason: NotificationReason) -> Binding<Bool> {
        Binding(
            get: { enabledReasons.contains(reason) },
            set: { enabled in
                if enabled {
                    enabledReasons.insert(reason)
                } else {
                    enabledReasons.remove(reason)
                }
            }
        )
    }

    private func bannerBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { bannerDelivery[id, default: false] },
            set: { bannerDelivery[id] = $0 }
        )
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        Section {
            DoubleBezel(cornerRadius: GHNRadius.innerGroup) {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(12)
            }
        } header: {
            Text(title)
                .font(GHNFont.panelTitle)
                .foregroundStyle(GHNColor.textSecondary)
        }
    }
}

private extension NotificationReason {
    var displayName: String {
        switch self {
        case .assign: return "Assign"
        case .author: return "Author"
        case .ciActivity: return "CI activity"
        case .comment: return "Comment"
        case .manual: return "Manual"
        case .mention: return "Mention"
        case .reviewRequested: return "Review requested"
        case .securityAlert: return "Security alert"
        case .stateChange: return "State change"
        case .subscribed: return "Subscribed"
        case .teamMention: return "Team mention"
        }
    }
}
