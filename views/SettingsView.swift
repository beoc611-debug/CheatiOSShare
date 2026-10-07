import SwiftUI

struct SettingsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    @State private var ios27Expanded = true
    @State private var showChangeKey = false
    @State private var showFullKey = false
    @State private var changeKeyToast: String? = nil

    var body: some View {
        ZStack {
            AppTheme.cyberBase.ignoresSafeArea()
            Image("AppBg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.14)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                customNavBar

                ScrollView {
                    VStack(spacing: 18) {
                        licenseSectionHeader
                        licenseCard
                        appInfoCard
                        deviceSectionHeader
                        deviceCard
                        verifiedVersionsHeader
                        verifiedVersionsCard
                        infoNoteCard
                        footerText
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .sheet(isPresented: $showChangeKey) {
                    KeyEntryView(
                        isChangingKey: true,
                        onKeyChanged: { old, new in
                            withAnimation(.spring(response: 0.35)) {
                                changeKeyToast = "Đổi key thành công\n\(old) → \(new)"
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                                withAnimation { changeKeyToast = nil }
                            }
                        }
                    )
                }
            }

            // Toast overlay after key change
            if let msg = changeKeyToast {
                VStack {
                    Spacer()
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(red: 0.24, green: 0.88, blue: 0.52))
                            Text(msg.components(separatedBy: "\n").first ?? "")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text(msg.components(separatedBy: "\n").dropFirst().joined())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.neonCyan)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.04, green: 0.22, blue: 0.10).opacity(0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(red: 0.24, green: 0.88, blue: 0.52).opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0.24, green: 0.88, blue: 0.52).opacity(0.20), radius: 16, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
            }
        }
        .toolbarHidden15()
    }

    // MARK: - Custom Nav Bar

    private var customNavBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .overlay(Circle().strokeBorder(AppTheme.neonRed.opacity(0.35), lineWidth: 1))
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
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - License Section

    private var licenseSectionHeader: some View {
        HStack(spacing: 10) {
            redAccentBar
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.neonRed)
            Text("GIẤY PHÉP & BẢN QUYỀN")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .tracking15(1.0)
            LinearGradient(colors: [AppTheme.neonRed.opacity(0.25), Color.clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            vipStatusPill
        }
    }

    private var vipStatusPill: some View {
        let isVip  = licenseGate.isVipEligible
        let green  = Color(red: 0.24, green: 0.88, blue: 0.52)
        let gold   = Color(red: 1.00, green: 0.78, blue: 0.18)
        let tint   = isVip ? gold : green
        let label  = isVip ? "VIP" : "ACTIVE"
        let icon   = isVip ? "crown.fill" : "checkmark.seal.fill"
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((isVip ? Color(red: 0.22, green: 0.16, blue: 0.02) : Color(red: 0.04, green: 0.22, blue: 0.10)).opacity(0.85), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1))
        .shadow(color: tint.opacity(0.25), radius: 6)
    }

    private var licenseCard: some View {
        VStack(spacing: 0) {
            // Key display row
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.neonRed.opacity(0.16))
                        .overlay(Circle().strokeBorder(AppTheme.neonRed.opacity(0.38), lineWidth: 1))
                        .shadow(color: AppTheme.neonRed.opacity(0.22), radius: 8)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.neonRed)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Mã Key")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.50))
                    let rawKey = licenseGate.storedKeyCode ?? ""
                    let displayedKey = showFullKey
                        ? (rawKey.isEmpty ? "—" : rawKey)
                        : (licenseGate.maskedKeyCode.isEmpty ? "—" : licenseGate.maskedKeyCode)
                    Text(displayedKey)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.neonCyan)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showFullKey.toggle() }
                } label: {
                    Image(systemName: showFullKey ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: 0.38))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            rowDivider

            // Expiry row
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.10, green: 0.75, blue: 0.40).opacity(0.18))
                        .overlay(Circle().strokeBorder(Color(red: 0.20, green: 0.80, blue: 0.45).opacity(0.40), lineWidth: 1))
                        .shadow(color: Color(red: 0.20, green: 0.80, blue: 0.45).opacity(0.22), radius: 8)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.24, green: 0.88, blue: 0.52))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Thời hạn còn lại")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.50))
                    Text(licenseGate.remainingTimeText(language: language))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.24, green: 0.88, blue: 0.52))
                }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            rowDivider

            // Change key button
            Button { showChangeKey = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .bold))
                    Text("Đổi Mã Key Khác")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(white: 0.38))
                }
                .foregroundStyle(AppTheme.neonCyan)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
        }
        .darkCard()
        .shadow(color: AppTheme.neonRed.opacity(0.07), radius: 16, y: 4)
    }

    // MARK: - App Info Card

    private var appInfoCard: some View {
        HStack(spacing: 16) {
            AppLogo(size: 68)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("CheatiOSVip")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Premium")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.neonRed)
                }

                Text(language.text("common.version", appVersion))
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.55))

                Text(language.text("common.build", String(AppInfo.buildNumber)))
                    .font(.system(size: 11, weight: .semibold).monospaced())
                    .foregroundStyle(AppTheme.neonCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.neonCyan.opacity(0.10), in: Capsule())
                    .overlay(Capsule().strokeBorder(AppTheme.neonCyan.opacity(0.40), lineWidth: 1))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .darkCard()
        .padding(.top, 4)
    }

    // MARK: - Section Headers

    private var deviceSectionHeader: some View {
        HStack(spacing: 10) {
            redAccentBar
            Image(systemName: "iphone")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.neonRed)
            Text(language.text("common.device").uppercased())
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .tracking15(1.0)
            LinearGradient(colors: [AppTheme.neonRed.opacity(0.25), Color.clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
    }

    private var verifiedVersionsHeader: some View {
        HStack(spacing: 10) {
            redAccentBar
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.neonRed)
            Text(language.text("settings.verified_versions").uppercased())
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .tracking15(1.0)
            LinearGradient(colors: [AppTheme.neonRed.opacity(0.25), Color.clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            supportStatusPill
        }
    }

    private var redAccentBar: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(LinearGradient(
                colors: [AppTheme.neonRed, Color(red: 0.70, green: 0.05, blue: 0.10)],
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: 3, height: 18)
            .shadow(color: AppTheme.neonRed.opacity(0.55), radius: 5)
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
            settingsRow(
                icon: "cpu",
                iconColor: AppTheme.techGlow,
                label: language.text("dashboard.hardware_model"),
                value: AppInfo.displayMachineName,
                valueColor: AppTheme.neonCyan
            )
            rowDivider
            settingsRow(
                icon: "apple.logo",
                iconColor: Color(red: 0.08, green: 0.65, blue: 0.95),
                label: language.text("settings.ios_version"),
                value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))",
                valueColor: AppTheme.neonCyan
            )
        }
        .darkCard()
        .shadow(color: Color.black.opacity(0.18), radius: 16, y: 4)
    }

    private func settingsRow(icon: String, iconColor: Color, label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .overlay(Circle().strokeBorder(iconColor.opacity(0.35), lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 42, height: 42)

            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(valueColor)
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
            versionRow(label: "iOS 15", number: "15", range: ExploitSupportPolicy.verifiedIOS15Range,
                       iconColor: Color(red: 0.20, green: 0.80, blue: 0.45))
            rowDivider
            versionRow(label: "iOS 16", number: "16", range: ExploitSupportPolicy.verifiedIOS16Range,
                       iconColor: Color(red: 0.35, green: 0.60, blue: 0.95))
            rowDivider
            versionRow(label: "iOS 17", number: "17", range: ExploitSupportPolicy.verifiedIOS17Range,
                       iconColor: Color(red: 0.68, green: 0.35, blue: 1.00))
            rowDivider
            versionRow(label: "iOS 18", number: "18", range: ExploitSupportPolicy.verifiedIOS18Range,
                       iconColor: AppTheme.techGlow)
            rowDivider
            versionRow(label: "iOS 26", number: "26", range: ExploitSupportPolicy.verifiedIOS26Range,
                       iconColor: AppTheme.neonCyan)
            rowDivider
            ios27Section
        }
        .darkCard()
    }

    private var currentVersionRow: some View {
        let isOK = appState.isSupported
        let green = Color(red: 0.24, green: 0.88, blue: 0.52)
        let red   = Color(red: 0.95, green: 0.28, blue: 0.35)
        let tint  = isOK ? green : red
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.techGlow.opacity(0.15))
                    .overlay(Circle().strokeBorder(AppTheme.techGlow.opacity(0.35), lineWidth: 1))
                Image(systemName: "speedometer")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.techGlow)
            }
            .frame(width: 42, height: 42)

            Text(language.text("settings.current_version"))
                .font(.system(size: 15))
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
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func versionRow(label: String, number: String, range: String, iconColor: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .overlay(Circle().strokeBorder(iconColor.opacity(0.35), lineWidth: 1))
                Text(number)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 42, height: 42)

            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.white)

            Spacer()

            Text(range)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(white: 0.55))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var ios27Section: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    ios27Expanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.neonRed.opacity(0.15))
                            .overlay(Circle().strokeBorder(AppTheme.neonRed.opacity(0.38), lineWidth: 1))
                        Text("27")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(AppTheme.neonRed)
                    }
                    .frame(width: 42, height: 42)

                    Text("iOS 27.0")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: ios27Expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(white: 0.45))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if ios27Expanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.horizontal, 18)

                    VStack(spacing: 0) {
                        ForEach(Array(ExploitSupportPolicy.verifiedIOS27Builds.enumerated()), id: \.offset) { index, version in
                            HStack(spacing: 12) {
                                Text("Beta \(version.beta)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.neonRed.opacity(0.90))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.neonRed.opacity(0.10), in: Capsule())
                                    .overlay(Capsule().strokeBorder(AppTheme.neonRed.opacity(0.30), lineWidth: 1))

                                Spacer()

                                Text(version.build)
                                    .font(.system(size: 13).monospaced())
                                    .foregroundStyle(AppTheme.neonCyan)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 11)

                            if index < ExploitSupportPolicy.verifiedIOS27Builds.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 1)
                                    .padding(.horizontal, 26)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppTheme.neonRed.opacity(0.18), lineWidth: 1))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Shared

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.horizontal, 18)
    }

    // MARK: - Info Note Card

    private var infoNoteCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.neonCyan.opacity(0.10))
                    .overlay(Circle().strokeBorder(AppTheme.neonCyan.opacity(0.30), lineWidth: 1))
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.neonCyan)
            }
            .frame(width: 42, height: 42)

            Text(language.text("settings.supported_versions_footer"))
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.50))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .darkCard()
    }

    // MARK: - Footer

    private var footerText: some View {
        Text("Ứng dụng này là một bản fork/remake dựa trên mã nguồn FilzaSlop và được phát triển, chỉnh sửa độc lập.\nỨng dụng này không phải là ứng dụng của 3105.")
            .font(.system(size: 12))
            .foregroundStyle(Color(white: 0.32))
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

// MARK: - Dark card modifier

private extension View {
    func darkCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(AppTheme.techCardFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 14, y: 4)
    }
}
