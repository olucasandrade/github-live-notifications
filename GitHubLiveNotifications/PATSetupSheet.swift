import SwiftUI

/// First-launch PAT entry sheet (UI-SPEC §3.2).
struct PATSetupSheet: View {
    @ObservedObject var auth: AuthController
    @Environment(\.dismiss) private var dismiss

    @State private var token = ""

    private static let classicTokenURL = URL(
        string: "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token"
    )!

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub Live Notifications")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                Text("Filtered GitHub signals in your menu bar — only what needs you.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SecureField("Personal access token", text: $token)
                .textFieldStyle(.roundedBorder)

            Link("Create a classic token", destination: Self.classicTokenURL)
                .font(.callout)

            Text("notifications · repo · read:user")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

            if case .failed(let message) = auth.validationState {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if let login = auth.login {
                Text("Signed in as **\(login)**")
                    .font(.callout)
            }

            HStack {
                Spacer()
                continueButton
            }
        }
        .padding(32)
        .frame(width: 440)
        .onChange(of: auth.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }

    private var continueButton: some View {
        Button(action: continueTapped) {
            Group {
                if auth.validationState == .validating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Continue")
                }
            }
            .frame(minWidth: 100)
        }
        .buttonStyle(.borderedProminent)
        .tint(GHNColor.accentSignal)
        .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || auth.validationState == .validating)
    }

    private func continueTapped() {
        Task {
            await auth.validateAndSave(token: token)
        }
    }
}
