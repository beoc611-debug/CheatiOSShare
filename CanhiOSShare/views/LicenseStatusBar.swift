import SwiftUI

struct LicenseStatusBar: View {
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @Environment(\.appLanguage) private var language
    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 14) {

            // Shield + lock icon
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.neonPurple.opacity(0.28), AppTheme.techGlow.opacity(0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppTheme.neonPurple.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.neonPurple.opacity(0.35), radius: 10)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.neonPurple, AppTheme.techGlow],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            .frame(width: 52, height: 52)

            // Key info
            VStack(alignment: .leading, spacing: 5) {
                Text("KEY \(licenseGate.maskedKeyCode)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.10, green: 0.88, blue: 0.52))
                        .frame(width: 7, height: 7)
                        .shadow(color: Color(red: 0.10, green: 0.88, blue: 0.52).opacity(0.75), radius: 4)
                    Text(licenseGate.remainingTimeText(language: language))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.14, green: 0.90, blue: 0.56))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Info button
            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(red: 0.42, green: 0.52, blue: 0.72))
            }
            .buttonStyle(.plain)

            // ĐỔI KEY button
            Button {
                licenseGate.changeKey()
            } label: {
                Text("ĐỔI KEY")
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(0.6)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.neonPurple, AppTheme.techGlow],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: AppTheme.neonPurple.opacity(0.60), radius: 12, y: 3)
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color(red: 0.028, green: 0.046, blue: 0.108).opacity(0.96))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.neonPurple.opacity(0.65), AppTheme.techGlow.opacity(0.40)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.neonPurple.opacity(0.22), radius: 20, y: -4)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showInfo) {
            LicenseInfoSheetView()
                .environmentObject(licenseGate)
        }
    }
}
