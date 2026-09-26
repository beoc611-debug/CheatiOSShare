import SwiftUI

struct FakeAppSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabled: Bool = UserDefaults.standard.bool(forKey: "fakeAppEnabled")
    @State private var isChanging = false

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.04, blue: 0.11).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(red: 0.20, green: 0.60, blue: 0.30).opacity(0.35),
                                             AppTheme.techGlow.opacity(0.20)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 72, height: 72)
                                .overlay(Circle().strokeBorder(Color(red: 0.20, green: 0.80, blue: 0.35).opacity(0.55), lineWidth: 1))
                                .shadow(color: Color(red: 0.10, green: 0.80, blue: 0.30).opacity(0.4), radius: 16)
                            Image(systemName: "theatermasks.fill")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color(red: 0.20, green: 0.90, blue: 0.40), AppTheme.techGlow],
                                    startPoint: .top, endPoint: .bottom
                                ))
                        }
                        Text("Ngụy trang ứng dụng")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Đổi icon ngoài màn hình chính")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.82))
                    }
                    .padding(.top, 28)

                    // Toggle card
                    infoCard {
                        VStack(alignment: .leading, spacing: 14) {
                            cardLabel("TÍNH NĂNG")
                            HStack(spacing: 14) {
                                ZStack {
                                    CutShape(cut: 10)
                                        .fill(Color(red: 0.10, green: 0.55, blue: 0.25).opacity(0.18))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "bird.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.25, green: 0.85, blue: 0.40))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Giả làm Flappy Bird")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("Đổi icon thành Flappy Bird")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.82))
                                }
                                Spacer()
                                if isChanging {
                                    ProgressView()
                                        .tint(Color(red: 0.25, green: 0.85, blue: 0.40))
                                        .scaleEffect(0.85)
                                } else {
                                    Toggle("", isOn: $isEnabled)
                                        .labelsHidden()
                                        .tint(Color(red: 0.20, green: 0.80, blue: 0.35))
                                        .onChange(of: isEnabled) { newVal in
                                            applyFakeMode(newVal)
                                        }
                                }
                            }
                        }
                    }

                    // Note card
                    infoCard {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.techGlow)
                                .padding(.top, 1)
                            Text("Hệ thống sẽ hỏi xác nhận đổi icon. Nhấn \"Change Icon\" để áp dụng. Tắt tính năng để khôi phục icon gốc.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.82))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Button { dismiss() } label: {
                        Text("Đóng")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [AppTheme.neonPurple, AppTheme.techGlow],
                                               startPoint: .leading, endPoint: .trailing),
                                in: CutShape(cut: 18)
                            )
                            .shadow(color: AppTheme.neonPurple.opacity(0.55), radius: 14, y: 4)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func applyFakeMode(_ enabled: Bool) {
        isChanging = true
        UserDefaults.standard.set(enabled, forKey: "fakeAppEnabled")

        // Try to write CFBundleDisplayName to Info.plist
        // Works when bundle is writable (eSign via SCR / TrollStore)
        let infoPlist = Bundle.main.bundlePath + "/Info.plist"
        let newName   = enabled ? "Flappy Bird" : "CheatiOSVip DSW"
        if FileManager.default.isWritableFile(atPath: infoPlist),
           let plist = NSMutableDictionary(contentsOfFile: infoPlist) {
            plist["CFBundleDisplayName"] = newName
            if plist.write(toFile: infoPlist, atomically: true) {
                // Notify SpringBoard to re-read the app metadata
                CFNotificationCenterPostNotification(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    CFNotificationName("com.apple.mobile.application_installed" as CFString),
                    nil, nil, true
                )
            }
        }

        // Change icon via system API
        let iconName: String? = enabled ? "FlappyBird" : nil
        UIApplication.shared.setAlternateIconName(iconName) { _ in
            DispatchQueue.main.async { isChanging = false }
        }
    }

    @ViewBuilder
    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.06, green: 0.09, blue: 0.20).opacity(0.90))
            .background(.ultraThinMaterial)
            .clipShape(CutShape(cut: 20))
            .overlay(
                CutShape(cut: 20).strokeBorder(
                    LinearGradient(colors: [AppTheme.techGlow.opacity(0.30), AppTheme.neonPurple.opacity(0.22)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
            )
    }

    @ViewBuilder
    private func cardLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .kerning(1.2)
            .foregroundStyle(Color(red: 0.42, green: 0.55, blue: 0.78))
    }
}
