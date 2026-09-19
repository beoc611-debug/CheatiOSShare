import SwiftUI
import UIKit

// Chi ve vien top + 2 canh ben (khong co canh day)
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

// Chi bo goc tren — thay the UnevenRoundedRectangle (iOS 17+) de tuong thich iOS 16
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
                                .padding(.bottom, 12)

                            gameGrid
                                .padding(.horizontal, 16)

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
                } else if selectedTab == 3 {
                    MakeToolsView()
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
                VStack(spacing: 0) {
                    LicenseStatusBar()
                        .padding(.bottom, 10)
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

                Text("Tr\u{1EE3} th\u{1EE7} game \u{00B7} An to\u{00E0}n \u{00B7} \u{1ED4}n \u{0111}\u{1ECB}nh")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
            }

            Spacer()

            // Gear button
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

    // MARK: - Game section header

    private var gameSectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.techGlow, AppTheme.neonPurple],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppTheme.techGlow.opacity(0.6), radius: 6)
                Text("DANH S\u{00C1}CH GAME")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .kerning(0.4)
                Spacer()
                HStack(spacing: 3) {
                    Text("Xem t\u{1EA5}t c\u{1EA3} (\(games.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.neonPurple.opacity(0.90))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.neonPurple.opacity(0.90))
                }
            }
            .padding(.horizontal, 20)

            // Decorative neon accent line
            LinearGradient(
                colors: [
                    AppTheme.neonPurple,
                    AppTheme.techGlow,
                    AppTheme.techGlow.opacity(0.08),
                    .clear
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 2)
            .clipShape(Capsule())
            .padding(.horizontal, 20)
        }
    }

    private var gameGrid: some View {
        VStack(spacing: 10) {
            let featured = Array(games.prefix(2))
            let rest = Array(games.dropFirst(2))
            let pairs: [[RemoteGameSummary]] = stride(from: 0, to: rest.count, by: 2)
                .map { Array(rest[$0..<min($0+2, rest.count)]) }

            if !featured.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(featured.enumerated()), id: \.element.id) { idx, game in
                        Button { selectedGame = game } label: {
                            GameCardView(
                                title: game.name,
                                subtitle: game.bundleID,
                                bannerColor: AppTheme.resolvedBannerColor(game.bannerColor),
                                iconURL: game.iconURL,
                                systemIconName: "app.fill",
                                actionLabel: game.type == "app" ? "M\u{1EDE} \u{1EE8}NG D\u{1EE4}NG" : "M\u{1EDE} GAME",
                                isFeatured: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if featured.count == 1 { Spacer().frame(maxWidth: .infinity) }
                }
            }

            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                HStack(spacing: 10) {
                    ForEach(pair) { game in
                        Button { selectedGame = game } label: {
                            GameCardView(
                                title: game.name,
                                subtitle: game.bundleID,
                                bannerColor: AppTheme.resolvedBannerColor(game.bannerColor),
                                iconURL: game.iconURL,
                                systemIconName: "app.fill",
                                actionLabel: game.type == "app" ? "M\u{1EDE} \u{1EE8}NG D\u{1EE4}NG" : "M\u{1EDE} GAME",
                                isFeatured: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if pair.count == 1 { Spacer().frame(maxWidth: .infinity) }
                }
            }
        }
    }

    // MARK: - Bottom Tab Bar

    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "gamecontroller.fill", label: "Game", index: 0)
            tabItem(icon: "wrench.and.screwdriver.fill", label: "Vip Tools", index: 1)
            tabItem(icon: "network.badge.shield.half.filled", label: "Next DNS", index: 2)
            tabItem(icon: "wand.and.stars", label: "Tools Make", index: 3)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            ZStack {
                Color(red: 0.05, green: 0.04, blue: 0.16).opacity(0.98)
                LinearGradient(
                    colors: [AppTheme.neonPurple.opacity(0.07), .clear],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LinearGradient(
                    colors: [AppTheme.neonPurple.opacity(0.42), AppTheme.techGlow.opacity(0.20), AppTheme.neonPurple.opacity(0.42)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 0.8)
        }
    }

    private func tabItem(icon: String, label: String, index: Int) -> some View {
        let active = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: active ? .bold : .regular))
                    .foregroundStyle(active ? AppTheme.neonPurple : Color(red: 0.40, green: 0.48, blue: 0.68))
                    .shadow(color: active ? AppTheme.neonPurple.opacity(0.65) : .clear, radius: 8)
                Text(label)
                    .font(.system(size: 10, weight: active ? .bold : .medium))
                    .foregroundStyle(active ? AppTheme.neonPurple : Color(red: 0.40, green: 0.48, blue: 0.68))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var emptyGamesView: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(AppTheme.techGlow.opacity(0.6))

            Text("App \u{0111}ang ti\u{1EBF}n h\u{00E0}nh n\u{00E2}ng c\u{1EA5}p m\u{1EDB}i, truy c\u{1EAD}p ngay Telegram \u{0111}\u{1EC3} nh\u{1EAD}n th\u{00F4}ng b\u{00E1}o m\u{1EDB}i")
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
                    Text("V\u{00E0}o ngay")
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

                Text("Ch\u{1ECD}n ng\u{00F4}n ng\u{1EEF} / Choose Language")
                    .font(.headline.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                VStack(spacing: 10) {
                    languageOptionButton(title: "Ti\u{1EBF}ng Vi\u{1EC7}t \u{1F1FB}\u{1F1F3}", code: .vietnamese)
                    languageOptionButton(title: "English \u{1F1FA}\u{1F1F8}", code: .english)
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
    var actionLabel: String = "M\u{1EDE} GAME"
    var isFeatured: Bool = false

    @State private var borderRotation: Double = 0

    private var cornerBadge: (text: String, color: Color)? {
        let n = title.lowercased()
        if n.contains("free fire") || n.contains("pubg") || n.contains("cod") || n.contains("battle") {
            return ("HOT", Color(red: 0.90, green: 0.12, blue: 0.20))
        }
        if actionLabel == "M\u{1EDE} \u{1EE8}NG D\u{1EE4}NG" {
            return ("PRO", Color(red: 0.32, green: 0.18, blue: 0.90))
        }
        return nil
    }

    private var iconSize: CGFloat { isFeatured ? 82 : 68 }
    private var cardHeight: CGFloat { isFeatured ? 172 : 138 }
    private var cornerRadius: CGFloat { 18 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Full-bleed background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.02, blue: 0.16),
                    bannerColor.opacity(0.28),
                    Color(red: 0.03, green: 0.02, blue: 0.12)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Inner top highlight
            LinearGradient(
                colors: [.white.opacity(0.06), .clear],
                startPoint: .top, endPoint: .center
            )

            // Atmospheric glow behind icon
            RadialGradient(
                colors: [bannerColor.opacity(0.40), bannerColor.opacity(0.10), .clear],
                center: .center, startRadius: 0, endRadius: 80
            )
            .padding(.bottom, cardHeight * 0.30)
            .padding(.top, 8)

            // Game icon — centered upper area
            iconView
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [bannerColor.opacity(0.95), bannerColor.opacity(0.40)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: bannerColor.opacity(0.95), radius: isFeatured ? 12 : 9)
                .shadow(color: bannerColor.opacity(0.50), radius: isFeatured ? 26 : 20, y: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.bottom, cardHeight * 0.33)

            // Bottom info strip with divider + arrow
            VStack(spacing: 0) {
                Divider()
                    .overlay(bannerColor.opacity(0.28))

                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: isFeatured ? 13.5 : 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 0.18, green: 0.92, blue: 0.48))
                                .frame(width: 5, height: 5)
                                .shadow(color: Color(red: 0.18, green: 0.92, blue: 0.48), radius: 4)
                            Text("\u{0110}\u{00E3} s\u{1EB5}n s\u{00E0}ng")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(Color(red: 0.18, green: 0.92, blue: 0.48))
                        }
                    }
                    Spacer()
                    // Arrow button
                    Image(systemName: "arrow.right")
                        .font(.system(size: isFeatured ? 11 : 10, weight: .bold))
                        .foregroundStyle(bannerColor)
                        .padding(6)
                        .background(bannerColor.opacity(0.18), in: Circle())
                        .overlay(Circle().strokeBorder(bannerColor.opacity(0.55), lineWidth: 1))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.88)],
                    startPoint: .top, endPoint: .bottom
                )
            )

            // HOT / PRO badge — top right (pill shape)
            if let badge = cornerBadge {
                Text(badge.text)
                    .font(.system(size: 8.5, weight: .black))
                    .kerning(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [badge.color, badge.color.opacity(0.80)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: badge.color.opacity(0.70), radius: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            bannerColor.opacity(0.92),
                            bannerColor.opacity(0.22),
                            bannerColor.opacity(0.60),
                            bannerColor.opacity(0.10)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    AngularGradient(
                        colors: [
                            .clear,
                            AppTheme.techGlow.opacity(0.0),
                            AppTheme.techGlow.opacity(0.85),
                            AppTheme.neonPurple.opacity(0.90),
                            AppTheme.techGlow.opacity(0.85),
                            AppTheme.techGlow.opacity(0.0),
                            .clear
                        ],
                        center: .center,
                        startAngle: .degrees(borderRotation),
                        endAngle: .degrees(borderRotation + 360)
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: bannerColor.opacity(0.45), radius: isFeatured ? 20 : 16, x: 0, y: isFeatured ? 8 : 6)
        .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 4)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                borderRotation = 360
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
            bannerColor.opacity(0.28)
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
