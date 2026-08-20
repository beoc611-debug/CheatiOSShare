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
    @State private var gameNotices: [String: GameNotice] = [:]
    @State private var selectedGame: RemoteGameSummary? = nil
    @State private var pendingGame: RemoteGameSummary? = nil
    @State private var activeGameNotice: GameNotice? = nil
    @AppStorage("language.hasPicked") private var hasPickedLanguage = false
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

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
        NavigationStack {
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

                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(games) { game in
                                    Button {
                                        if let notice = gameNotices[game.id] {
                                            pendingGame = game
                                            activeGameNotice = notice
                                        } else {
                                            selectedGame = game
                                        }
                                    } label: {
                                        GameCardView(
                                            title: game.name,
                                            subtitle: game.bundleID.isEmpty ? " " : game.bundleID,
                                            bannerColor: AppTheme.resolvedBannerColor(game.bannerColor),
                                            iconURL: game.iconURL,
                                            systemIconName: "app.fill"
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
                } else {
                    appsTabContent
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .refreshable {
                await loadGames()
                await checkAnnouncement()
            }
            .task { await loadGames() }
            .task { await checkAnnouncement() }
            .task { await loadGameNotices() }
            .navigationDestination(isPresented: Binding(
                get: { selectedGame != nil },
                set: { if !$0 { selectedGame = nil } }
            )) {
                if let game = selectedGame {
                    GamePatchesView(game: game, store: store)
                }
            }
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
            .sheet(item: $activeGameNotice) { notice in
                GameNoticeSheetView(notice: notice) {
                    activeGameNotice = nil
                    selectedGame = pendingGame
                    pendingGame = nil
                }
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
            tabItem(icon: "square.grid.2x2.fill", label: "Ứng dụng", index: 1)
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

    // MARK: - Apps tab placeholder

    private var appsTabContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                cyberHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                VStack(spacing: 20) {
                    ZStack {
                        // Outer glow
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(AppTheme.neonPurple.opacity(0.08))
                            .frame(width: 110, height: 110)
                            .blur(radius: 20)

                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color(red: 0.030, green: 0.050, blue: 0.115).opacity(0.82))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [AppTheme.neonPurple.opacity(0.55), AppTheme.techGlow.opacity(0.35)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .frame(width: 90, height: 90)

                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.neonPurple, AppTheme.techGlow],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: AppTheme.neonPurple.opacity(0.60), radius: 12)
                    }

                    VStack(spacing: 8) {
                        Text("Ứng dụng")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)

                        HStack(spacing: 8) {
                            // Animated dots
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(AppTheme.neonPurple.opacity(0.60))
                                    .frame(width: 6, height: 6)
                            }
                        }

                        Text("Đang phát triển")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(red: 0.46, green: 0.56, blue: 0.76))
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)

                Spacer(minLength: 32)
            }
        }
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
                if let url = URL(string: "https://t.me/crackcyipa") {
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

    private func loadGameNotices() async {
        let fetched = await PatchHubService.fetchGameNotices()
        gameNotices = fetched
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

    var body: some View {
        VStack(spacing: 0) {
            // Banner with icon
            ZStack {
                LinearGradient(
                    colors: [
                        bannerColor.opacity(0.60),
                        Color(red: 0.04, green: 0.05, blue: 0.13)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Glow behind icon
                Circle()
                    .fill(bannerColor.opacity(0.28))
                    .blur(radius: 20)
                    .frame(width: 80, height: 80)

                iconView
                    .frame(width: 62, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                    )
                    .shadow(color: bannerColor.opacity(0.50), radius: 16, y: 6)
            }
            .frame(height: 100)

            // Info + action
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.techGlow.opacity(0.85))
                        .lineLimit(1)
                }

                // Action button (visual — card NavigationLink handles tap)
                HStack(spacing: 4) {
                    Spacer()
                    Text("MỞ GAME")
                        .font(.system(size: 11, weight: .heavy))
                        .kerning(0.8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Spacer()
                }
                .padding(.vertical, 7)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [AppTheme.neonPurple.opacity(0.90), AppTheme.techGlow.opacity(0.95)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .shadow(color: AppTheme.neonPurple.opacity(0.45), radius: 8, y: 2)
            }
            .padding(12)
            .background(Color(red: 0.045, green: 0.062, blue: 0.122))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppTheme.techCardStroke, lineWidth: 1)
        )
        .shadow(color: AppTheme.neonPurple.opacity(0.16), radius: 14, y: 5)
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
        Image(systemName: systemIconName)
            .resizable()
            .scaledToFit()
            .padding(14)
            .foregroundStyle(.white)
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

