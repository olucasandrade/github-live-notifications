import Foundation
import ServiceManagement

/// Registers the app for launch at login via `SMAppService` (PLAN.md: App chrome).
@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            applyRegistration()
        }
    }

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    private func applyRegistration() {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}
