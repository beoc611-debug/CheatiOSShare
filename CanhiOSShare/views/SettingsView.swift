import SwiftUI

struct SettingsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    @State private var ios27Expanded = true

    /* Tạm ẩn mục Ngôn ngữ
    Picker(language.text("settings.language"), selection: $languageCode) {
        ForEach(AppLanguage.allCases) { option in
            Text(option.displayName).tag(option.rawValue)
        }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    */

    var body: some View {
        ZStack {
            TechBackground()

            VStack(spacing: 0) {
                customNavBar

                ScrollView {
                    VStack(spacing: 18) {
                        appInfoCard
                        deviceSectionHeader
                        deviceCard
                        verifiedVersionsHeader
                        verifiedVersionsCard
                        infoNoteCard
                        footerText
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Custom Nav Bar

    private var customNavBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.04, green: 0.07, blue: 0.17).opacity(0.88))
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(
                                    colors: [AppTheme.techGlow.opacity(0.70), AppTheme.neonPurple.opacity(0.50)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                        )
                        .shadow(color: AppTheme.techGlow.opacity(0.28), radius: 10)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.92))

            Spacer()

            Text(language.text("settings.title"))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - App Info Card

    private var appInfoCard: some View {
        HStack(spacing: 16) {
            AppLogo(size: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text("CheatiOSVip DSW")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text(language.text("common.version", appVersion))
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 0.60, green: 0.68, blue: 0.82))

                Text(language.text("common.build", String(AppInfo.buildNumber)))
                    .font(.system(size: 11, weight: .semibold).monospaced())
                    .foregroundStyle(AppTheme.neonCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.04, green: 0.14, blue: 0.24).opacity(0.90), in: Capsule())
                    .overlay(Capsule().strokeBorder(AppTheme.neonCyan.opacity(0.60), lineWidth: 1))
                    .shadow(color: AppTheme.neonCyan.opacity(0.25), radius: 6)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .glassCard(cornerRadius: 24)
        .padding(.top, 6)
    }

    // MARK: - Section Headers

    private var deviceSectionHeader: some View {
        HStack(spacing: 10) {
            neonAccentBar
            Image(systemName: "iphone")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.neonPurple)
            Text(language.text("common.device").uppercased())
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color(red: 0.60, green: 0.70, blue: 0.88))
                .tracking(1.2)
            LinearGradient(colors: [AppTheme.techGlow.opacity(0.28), Color.clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
    }

    private var verifiedVersionsHeader: some View {
        HStack(spacing: 10) {
            neonAccentBar
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.neonPurple)
            Text(language.text("settings.verified_versions").uppercased())
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color(red: 0.60, green: 0.70, blue: 0.88))
                .tracking(1.2)
            LinearGradient(colors: [AppTheme.techGlow.opacity(0.28), Color.clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            supportStatusPill
        }
    }

    private var neonAccentBar: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(LinearGradient(colors: [AppTheme.neonCyan, AppTheme.techGlow], startPoint: .top, endPoint: .bottom))
            .frame(width: 3, height: 17)
            .shadow(color: AppTheme.neonCyan.opacity(0.70), radius: 5)
    }

    private var supportStatusPill: some View {
        let isOK = appState.isSupported
        let green = Color(red: 0.24, green: 0.88, blue: 0.52)
        let red   = Color(red: 0.95, green: 0.28, blue: 0.35)
        let tint  = isOK ? green : red
        return HStack(spacing: 4) {
            Image(systemName: isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
            Text(language.text(isOK ? "settings.supported" : "settings.unsupported"))
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((isOK ? Color(red: 0.04, green: 0.22, blue: 0.10) : Color(red: 0.22, green: 0.04, blue: 0.06)).opacity(0.85), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1))
        .shadow(color: tint.opacity(0.25), radius: 6)
    }

    // MARK: - Device Card

    private var deviceCard: some View {
        VStack(spacing: 0) {
            deviceRow(
                icon: "cpu",
                iconGradient: [AppTheme.techGlow, Color(red: 0.10, green: 0.35, blue: 0.82)],
                glowColor: AppTheme.techGlow,
                label: language.text("dashboard.hardware_model"),
                value: AppInfo.displayMachineName
            )
            rowDivider
            deviceRow(
                icon: "apple.logo",
                iconGradient: [AppTheme.neonCyan, Color(red: 0.08, green: 0.50, blue: 0.80)],
                glowColor: AppTheme.neonCyan,
                label: language.text("settings.ios_version"),
                value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))"
            )
        }
        .glassCard(cornerRadius: 22)
        .shadow(color: AppTheme.neonCyan.opacity(0.07), radius: 16, y: 4)
    }

    private func deviceRow(icon: String, iconGradient: [Color], glowColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(glowColor.opacity(0.40), lineWidth: 1)
                    )
                    .shadow(color: glowColor.opacity(0.28), radius: 8)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.neonCyan)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - Verified Versions Card

    private var verifiedVersionsCard: some View {
        VStack(spacing: 0) {
            currentVersionRow
            rowDivider
            versionRow(label: "iOS 17", number: "17", range: ExploitSupportPolicy.verifiedIOS17Range,
                       gradient: [Color(red: 0.58, green: 0.23, blue: 0.95), Color(red: 0.36, green: 0.18, blue: 0.80)],
                       glow: AppTheme.neonPurple)
            rowDivider
            versionRow(label: "iOS 18", number: "18", range: ExploitSupportPolicy.verifiedIOS18Range,
                       gradient: [Color(red: 0.14, green: 0.52, blue: 0.98), Color(red: 0.08, green: 0.35, blue: 0.80)],
                       glow: AppTheme.techGlow)
            rowDivider
            versionRow(label: "iOS 26", number: "26", range: ExploitSupportPolicy.verifiedIOS26Range,
                       gradient: [Color(red: 0.08, green: 0.74, blue: 0.96), Color(red: 0.06, green: 0.48, blue: 0.80)],
                       glow: AppTheme.neonCyan)
            rowDivider
            ios27Section
        }
        .glassCard(cornerRadius: 24)
    }

    private var currentVersionRow: some View {
        let isOK = appState.isSupported
        let green = Color(red: 0.24, green: 0.88, blue: 0.52)
        let red   = Color(red: 0.95, green: 0.28, blue: 0.35)
        let tint  = isOK ? green : red
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.18, green: 0.52, blue: 1.00), Color(red: 0.10, green: 0.35, blue: 0.82)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(AppTheme.techGlow.opacity(0.40), lineWidth: 1))
                    .shadow(color: AppTheme.techGlow.opacity(0.30), radius: 8)
                Image(systemName: "speedometer")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            Text(language.text("settings.current_version"))
                .font(.system(size: 16))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(language.text(isOK ? "settings.supported" : "settings.unsupported"))
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background((isOK ? Color(red: 0.04, green: 0.22, blue: 0.10) : Color(red: 0.22, green: 0.04, blue: 0.06)).opacity(0.85), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1))
            .shadow(color: tint.opacity(0.28), radius: 8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func versionRow(label: String, number: String, range: String, gradient: [Color], glow: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(glow.opacity(0.40), lineWidth: 1))
                    .shadow(color: glow.opacity(0.28), radius: 8)
                Text(number)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(.white)

            Spacer()

            Text(range)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.60, green: 0.70, blue: 0.88))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var ios27Section: some View {
        VStack(spacing: 0) {
            // Tap-to-expand row
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    ios27Expanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.45, green: 0.15, blue: 0.92), Color(red: 0.28, green: 0.10, blue: 0.72)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(AppTheme.neonPurple.opacity(0.45), lineWidth: 1))
                            .shadow(color: AppTheme.neonPurple.opacity(0.32), radius: 8)
                        Text("27")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)

                    Text("iOS 27.0")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: ios27Expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.50, green: 0.60, blue: 0.80))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Expanded beta builds panel
            if ios27Expanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(red: 0.18, green: 0.26, blue: 0.44).opacity(0.28))
                        .frame(height: 1)
                        .padding(.horizontal, 18)

                    VStack(spacing: 0) {
                        ForEach(Array(ExploitSupportPolicy.verifiedIOS27Builds.enumerated()), id: \.offset) { index, version in
                            HStack(spacing: 12) {
                                Text("Beta \(version.beta)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.neonPurple.opacity(0.90))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.neonPurple.opacity(0.10), in: Capsule())
                                    .overlay(Capsule().strokeBorder(AppTheme.neonPurple.opacity(0.32), lineWidth: 1))

                                Spacer()

                                Text(version.build)
                                    .font(.system(size: 13).monospaced())
                                    .foregroundStyle(AppTheme.neonCyan)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 11)

                            if index < ExploitSupportPolicy.verifiedIOS27Builds.count - 1 {
                                Rectangle()
                                    .fill(Color(red: 0.18, green: 0.26, blue: 0.44).opacity(0.20))
                                    .frame(height: 1)
                                    .padding(.horizontal, 26)
                            }
                        }
                    }
                    .background(Color(red: 0.022, green: 0.038, blue: 0.092).opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppTheme.neonPurple.opacity(0.22), lineWidth: 1)
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Shared Row Divider

    private var rowDivider: some View {
        Rectangle()
            .fill(Color(red: 0.18, green: 0.26, blue: 0.44).opacity(0.28))
            .frame(height: 1)
            .padding(.horizontal, 18)
    }

    // MARK: - Info Note Card

    private var infoNoteCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.techGlow.opacity(0.12))
                    .overlay(Circle().strokeBorder(AppTheme.techGlow.opacity(0.38), lineWidth: 1))
                    .shadow(color: AppTheme.techGlow.opacity(0.22), radius: 8)
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.neonCyan)
            }
            .frame(width: 42, height: 42)

            Text(language.text("settings.supported_versions_footer"))
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.80))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color(red: 0.030, green: 0.050, blue: 0.115).opacity(0.75))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [AppTheme.neonCyan.opacity(0.38), AppTheme.techGlow.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.techGlow.opacity(0.07), radius: 14, y: 4)
    }

    // MARK: - Footer

    private var footerText: some View {
        Text("Ứng dụng này là một bản fork/remake dựa trên mã nguồn FilzaSlop và được phát triển, chỉnh sửa độc lập.\nỨng dụng này không phải là ứng dụng của 3105.")
            .font(.system(size: 12))
            .foregroundStyle(Color(red: 0.38, green: 0.46, blue: 0.60))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 10)
    }

    // MARK: - Helper

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }
}

// MARK: - Glass card modifier (local convenience)

private extension View {
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(Color(red: 0.030, green: 0.050, blue: 0.115).opacity(0.82))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [AppTheme.techGlow.opacity(0.50), AppTheme.neonPurple.opacity(0.32)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: AppTheme.techGlow.opacity(0.09), radius: 20, y: 5)
    }
}
