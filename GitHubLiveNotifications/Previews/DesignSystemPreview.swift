import SwiftUI

#if DEBUG
private struct DesignSystemSample: View {
    var body: some View {
        DoubleBezel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(GHNColor.accentSignal)
                        .frame(width: 8, height: 8)
                    Text("Updated 3m ago")
                        .font(GHNFont.mono)
                        .foregroundStyle(GHNColor.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: GHNRadius.innerGroup, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Design tokens")
                        .font(GHNFont.panelTitle)
                        .foregroundStyle(GHNColor.textPrimary)
                    Text("owner/repo · mention · 2m")
                        .font(GHNFont.meta)
                        .foregroundStyle(GHNColor.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .padding(16)
        .background(GHNColor.surfaceCanvas)
        .frame(width: 360)
    }
}

#Preview("Light") {
    DesignSystemSample()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    DesignSystemSample()
        .preferredColorScheme(.dark)
}
#endif
