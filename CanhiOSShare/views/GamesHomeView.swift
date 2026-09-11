import SwiftUI
import UIKit

// Chỉ vẽ viền top + 2 cạnh bên (không có cạnh đáy)
private struct TabBarTopBorder: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                 radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                 radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

// Chỉ bo góc trên — thay thế UnevenRoundedRectangle (iOS 17+) để tương thích iOS 16
private struct TopRoundedShape: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                 radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                 radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct GamesHomeView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @StateObject private var store = PatchProjectStore()
    @State private var games: [RemoteGameSummary] = []
    @State private var isLoadingGames = false
    @State private var showLanguagePicker = false
    @State private var announcement: Announcement?
    @State private var shownAnnouncementIDs: Set<String> = []
    @State private var selectedTab = 0
    @State private var selectedGame: RemoteGameSummary? = nil
    @State private var contactURL: URL? = URL(string: "https://t.me/crackcyipa")
    @AppStorage("language.hasPicked") private var hasPickedLanguage = false
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue


    var body: some View {
        ZStack {
            homeStack

            if showLanguagePicker {
                languagePickerOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showLanguagePicker)
        .task {
            if !hasPickedLanguage { showLanguagePicker = true }
        }
    }

    // MARK: - Home stack

    private var homeStack: some View {
        AnyNavigationStack {
            ZStack {
                TechBackground()

                if selectedTab == 0 {
                    ScrollView {
                        VStack(spacing: 0) {
                            cyberHeader
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .padding(.bottom, 16)

                            deviceInfoCard
                                .padding(.horizontal, 16)

                            gameSectionHeader
                                .padding(.top, 22)
                                .padding(.bottom, 4)

                            LazyVStack(spacing: 12) {
                                ForEach(games) { game in
                                    Button {
                                        selectedGame = game
                                    } label: {
                                        GameCardView(
                                            title: game.name,
                                            subtitle: game.bundleID.isEmpty ? " " : game.bundleID,
                                            bannerColor: AppTheme.resolvedBannerColor(game.bannerColor),
                                            iconURL: game.iconURL,
                                            systemIconName: "app.fill",
                                            actionLabel: game.type == "app" ? "MỞ ỨNG DỤNG" : "MỞ GAME"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 6)

                            if games.isEmpty && !isLoadingGames {
                                emptyGamesView
                                    .padding(.top, 24)
                            }

                            Spacer(minLength: 32)
                        }
                    }
                } else if selectedTab == 1 {
                    VipToolsView()
                } else if selectedTab == 2 {
                    NextDNSView()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .refreshable {
                await loadGames()
                await checkAnnouncement()
            }
            .task { await loadGames() }
            .task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await checkAnnouncement()
            }
            .task { if let fetched = await PatchHubService.fetchContactURL() { contactURL = fetched } }
            .background(
                NavigationLink(
                    isActive: Binding(
                        get: { selectedGame != nil },
                        set: { if !$0 { selectedGame = nil } }
                    ),
                    destination: {
                        if let game = selectedGame {
                            GamePatchesView(game: game, store: store)
                        } else {
                            EmptyView()
                        }
                    },
                    label: { EmptyView() }
                )
                .hidden()
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    LicenseStatusBar()
                    bottomTabBar
                }
            }
            .toast($licenseGate.activationToast)
            .sheet(item: $announcement) { item in
                AnnouncementSheetView(announcement: item)
            }
            .sheet(item: $draftCoordinator.request) { request in
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false,
                    initialDraft: request.draft
                ) { project, password in
                    store.create(project: project, password: password)
                    draftCoordinator.clear()
                }
            }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: - Custom header

    private var cyberHeader: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                // Title row: "CheatiOSVip" + crown+DSW block
                HStack(alignment: .bottom, spacing: 8) {
                    Text("CheatiOSVip")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.26, green: 0.55, blue: 1.00),
                                         Color(red: 0.48, green: 0.37, blue: 1.00)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    VStack(spacing: 0) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.neonPurple, Color(red: 0.55, green: 0.25, blue: 0.90)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("DSW")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.neonPurple, Color(red: 0.45, green: 0.20, blue: 0.80)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .padding(.bottom, 2)
                }

                Text("Trợ thủ game · An toàn · Ổn định")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
            }

            Spacer()

            // Gear button — square rounded
            NavigationLink {
                SettingsView()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(AppTheme.cyberBase.opacity(0.80))
                        .frame(width: 46, height: 46)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [AppTheme.neonPurple.opacity(0.80),
                                                 AppTheme.techGlow.opacity(0.40)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: AppTheme.neonPurple.opacity(0.30), radius: 10)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppTheme.neonPurple)
                }
            }
            .accessibilityLabel(language.text("tab.settings"))
        }
    }

    // MARK: - Device info card

    private var deviceInfoCard: some View {
        VStack(spacing: 0) {
            deviceInfoRow(
                icon: "apple.logo",
                iconColor: Color(red: 0.68, green: 0.28, blue: 0.98),
                label: language.text("settings.ios_version"),
                value: shortOSVersion,
                valueColor: AppTheme.neonCyan
            )

            infoRowDivider

            deviceInfoRow(
                icon: "iphone",
                iconColor: AppTheme.techGlow,
                label: language.text("common.device"),
                value: AppInfo.hardwareDisplayName,
                valueColor: .white
            )

            infoRowDivider

            deviceInfoRow(
                icon: appState.isSupported ? "checkmark.seal.fill" : "xmark.seal.fill",
                iconColor: appState.isSupported ? Color(red: 0.10, green: 0.85, blue: 0.50) : .red,
                label: language.text("settings.support"),
                value: language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"),
                valueColor: appState.isSupported ? Color(red: 0.10, green: 0.90, blue: 0.52) : .red,
                glowColor: appState.isSupported ? Color(red: 0.10, green: 0.85, blue: 0.50).opacity(0.55) : .red.opacity(0.55)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard()
    }

    private var infoRowDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.clear, AppTheme.techGlow.opacity(0.18), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.5)
            .padding(.vertical, 9)
    }

    private func deviceInfoRow(
        icon: String,
        iconColor: Color,
        label: String,
        value: String,
        valueColor: Color = .white,
        glowColor: Color = .clear
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundStyle(valueColor)
                .shadow(color: glowColor, radius: 5)
        }
    }

    private var shortOSVersion: String {
        let v = AppInfo.osVersion
        return v.hasSuffix(".0") ? String(v.dropLast(2)) : v
    }

    // MARK: - Game section

    private var gameSectionHeader: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, AppTheme.techGlow.opacity(0.45)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            HStack(spacing: 6) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.techGlow, AppTheme.neonPurple],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppTheme.techGlow.opacity(0.60), radius: 6)
                Text("GAME HỖ TRỢ")
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(1.5)
                    .foregroundStyle(Color(red: 0.52, green: 0.68, blue: 0.95))
            }
            .fixedSize()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.techGlow.opacity(0.45), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Bottom Tab Bar

    private var bottomTabBar: some View {
        let shape = TopRoundedShape(radius: 22)
        return HStack(spacing: 0) {
            tabItem(icon: "gamecontroller.fill", label: "Game", index: 0)
            tabItem(icon: "wrench.and.screwdriver.fill", label: "Vip Tools", index: 1)
            tabItem(icon: "network.badge.shield.half.filled", label: "Next DNS", index: 2)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .clipShape(shape)
        .overlay(
            TabBarTopBorder(radius: 22)
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.techGlow.opacity(0.40), AppTheme.neonPurple.opacity(0.30)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.neonPurple.opacity(0.14), radius: 16, y: -3)
    }

    private func tabItem(icon: String, label: String, index: Int) -> some View {
        let active = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: active ? .bold : .medium))
                    .foregroundStyle(active ? AppTheme.neonPurple : Color(red: 0.42, green: 0.50, blue: 0.68))
                    .shadow(color: active ? AppTheme.neonPurple.opacity(0.65) : .clear, radius: 8)
                Text(label)
                    .font(.system(size: 11, weight: active ? .bold : .medium))
                    .foregroundStyle(active ? AppTheme.neonPurple : Color(red: 0.42, green: 0.50, blue: 0.68))
                // Active dot indicator
                Circle()
                    .fill(active ? AppTheme.neonPurple : Color.clear)
                    .frame(width: 4, height: 4)
                    .shadow(color: active ? AppTheme.neonPurple.opacity(0.85) : .clear, radius: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private var emptyGamesView: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(AppTheme.techGlow.opacity(0.6))

            Text("App đang tiến hành nâng cấp mới, truy cập ngay Telegram để nhận thông báo mới")
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.45, green: 0.58, blue: 0.80))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if let url = contactURL {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Vào ngay")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [AppTheme.neonPurple, AppTheme.techGlow],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .shadow(color: AppTheme.neonPurple.opacity(0.45), radius: 10, y: 3)
            }
        }
    }

    // MARK: - Language picker overlay

    private var languagePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(AppTheme.techGlow.opacity(0.15))
                        .frame(width: 60, height: 60)
                        .blur(radius: 8)
                    Image(systemName: "globe")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.neonCyan, AppTheme.techGlow],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                Text("Chọn ngôn ngữ / Choose Language")
                    .font(.headline.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                VStack(spacing: 10) {
                    languageOptionButton(title: "Tiếng Việt 🇻🇳", code: .vietnamese)
                    languageOptionButton(title: "English 🇺🇸", code: .english)
                }
            }
            .padding(26)
            .frame(maxWidth: 320)
            .techCard()
            .padding(.horizontal, 32)
        }
        .preferredColorScheme(.dark)
    }

    private func languageOptionButton(title: String, code: AppLanguage) -> some View {
        Button {
            languageCode = code.rawValue
            hasPickedLanguage = true
            showLanguagePicker = false
        } label: {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(AppTheme.techCardFill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(AppTheme.techCardStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data loading

    private func loadGames() async {
        isLoadingGames = true
        if let fetched = try? await PatchHubService.fetchGames() {
            games = fetched
        }
        isLoadingGames = false
    }

    private func checkAnnouncement() async {
        guard case .announcement(let fetched) = await AnnouncementService.fetchState(),
              !shownAnnouncementIDs.contains(fetched.id)
        else { return }
        shownAnnouncementIDs.insert(fetched.id)
        announcement = fetched
    }
}

// MARK: - GameCardView

struct GameCardView: View {
    let title: String
    let subtitle: String
    let bannerColor: Color
    let iconURL: URL?
    let systemIconName: String
    var actionLabel: String = "MỞ GAME"

    private var category: (label: String, color: Color) {
        let n = title.lowercased()
        if n.contains("free fire") || n.contains("pubg") || n.contains("cod") || n.contains("battle") {
            return ("BATTLE ROYALE", Color(red: 1.0, green: 0.42, blue: 0.04))
        }
        if n.contains("liên quân") || n.contains("lien quan") || n.contains("arena") || n.contains("moba") || n.contains("mlbb") || n.contains("mobile legend") {
            return ("MOBA", Color(red: 0.12, green: 0.48, blue: 1.00))
        }
        if n.contains("shooter") || n.contains("sniper") || n.contains("fps") {
            return ("SHOOTER", Color(red: 0.92, green: 0.14, blue: 0.14))
        }
        if actionLabel == "MỞ ỨNG DỤNG" {
            return ("TIỆN ÍCH", Color(red: 0.08, green: 0.80, blue: 0.44))
        }
        return ("GAME", bannerColor)
    }

    private var cornerBadge: String? {
        let n = title.lowercased()
        if n.contains("free fire") || n.contains("pubg") || n.contains("cod") { return "HOT" }
        if actionLabel == "MỞ ỨNG DỤNG" { return "PRO" }
        return nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                // Icon zone with game-color atmosphere
                ZStack {
                    RadialGradient(
                        colors: [bannerColor.opacity(0.55), bannerColor.opacity(0.18), .clear],
                        center: .center, startRadius: 0, endRadius: 46
                    )
                    .frame(width: 92, height: 92)

                    iconView
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [bannerColor.opacity(0.95), bannerColor.opacity(0.45)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: bannerColor.opacity(1.0), radius: 7)
                        .shadow(color: bannerColor.opacity(0.6), radius: 22, y: 8)
                }
                .padding(.leading, 12)
                .padding(.trailing, 8)

                // Info column
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.label)
                        .font(.system(size: 8.5, weight: .black))
                        .kerning(0.7)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(category.color, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        )
                        .shadow(color: category.color.opacity(0.75), radius: 7, x: 0, y: 2)

                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.92, blue: 0.48))
                            .frame(width: 5, height: 5)
                            .shadow(color: Color(red: 0.18, green: 0.92, blue: 0.48), radius: 5)
                        Text("Đã sẵn sàng")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color(red: 0.18, green: 0.92, blue: 0.48))
                    }
                }

                Spacer()

                // Arrow button — neon ring
                ZStack {
                    Circle()
                        .fill(bannerColor.opacity(0.10))
                        .frame(width: 44, height: 44)
                        .shadow(color: bannerColor.opacity(0.65), radius: 12)
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [bannerColor.opacity(0.9), bannerColor.opacity(0.35)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(bannerColor)
                }
                .padding(.trailing, 14)
            }
            .frame(height: 90)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.07, green: 0.04, blue: 0.17), Color(red: 0.04, green: 0.02, blue: 0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    LinearGradient(
                        colors: [bannerColor.opacity(0.30), bannerColor.opacity(0.10), .clear],
                        startPoint: .leading, endPoint: UnitPoint(x: 0.52, y: 0.5)
                    )
                    LinearGradient(
                        colors: [.white.opacity(0.04), .clear, .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                bannerColor.opacity(0.95),
                                bannerColor.opacity(0.25),
                                bannerColor.opacity(0.55),
                                bannerColor.opacity(0.12)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: bannerColor.opacity(0.42), radius: 20, x: 0, y: 8)
            .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 4)

            // HOT / PRO corner badge
            if let badge = cornerBadge {
                Text(badge)
                    .font(.system(size: 8, weight: .black))
                    .kerning(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        badge == "HOT"
                            ? Color(red: 0.88, green: 0.15, blue: 0.15)
                            : Color(red: 0.32, green: 0.18, blue: 0.90),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .shadow(
                        color: (badge == "HOT" ? Color.red : Color(red: 0.32, green: 0.18, blue: 0.90)).opacity(0.65),
                        radius: 8
                    )
                    .padding(.top, 10)
                    .padding(.trailing, 60)
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconURL {
            CachedAsyncImage(url: iconURL) {
                placeholderIcon
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        ZStack {
            bannerColor.opacity(0.25)
            Image(systemName: systemIconName)
                .resizable()
                .scaledToFit()
                .padding(14)
                .foregroundStyle(.white)
        }
    }
}
// MARK: - CachedAsyncImage

struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let cached = RemoteImageCache.cachedImage(for: url) {
                uiImage = cached
            }
            if let fresh = await RemoteImageCache.fetchAndCache(url) {
                uiImage = fresh
            }
        }
    }
}

