import SwiftUI
import WebKit


struct GamePatchesView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseGate: LicenseGateStore
    let game: RemoteGameSummary
    @ObservedObject var store: PatchProjectStore

    @State private var isSyncing = false
    @State private var projectStates: [UUID: Bool] = [:]
    @State private var togglingProjectID: UUID?
    @State private var toast: ToastMessage?
    @State private var containers: [RemoteContainerSummary] = []
    @State private var selectedContainerID: String?
    @State private var containersLoaded = false
    @State private var gameNotice: GameNotice?
    @State private var showVideoSheet = false
    @State private var selectedFeatureTab = 0   // 0 = T�nh nang nhanh, 1 = Th�ng tin
    @State private var borderRotation: Double = 0

    private var currentContainerVideoUrl: String? {
        guard let id = selectedContainerID else { return nil }
        return containers.first(where: { $0.id == id })?.videoUrl
    }
    @AppStorage("patch.importedOnlineIDs") private var importedOnlineIDsRaw = ""
    @AppStorage("patch.gameAssignments") private var gameAssignmentsRaw = "{}"
    @AppStorage("patch.remoteToLocalMap") private var remoteToLocalMapRaw = "{}"
    @AppStorage("patch.remoteDisplayNames") private var remoteDisplayNamesRaw = "{}"
    @AppStorage("patch.containerAssignments") private var containerAssignmentsRaw = "{}"

    private var importedOnlineIDs: Set<String> {
        Set(importedOnlineIDsRaw.split(separator: ",").map(String.init))
    }

    private var gameAssignments: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(gameAssignmentsRaw.utf8))) ?? [:]
    }

    private var remoteToLocalMap: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(remoteToLocalMapRaw.utf8))) ?? [:]
    }

    private var remoteDisplayNames: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(remoteDisplayNamesRaw.utf8))) ?? [:]
    }

    private func displayName(for item: PatchLibraryItem) -> String {
        remoteDisplayNames[item.id.uuidString] ?? item.project?.name ?? language.text("patch.locked_project")
    }

    private var containerAssignments: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(containerAssignmentsRaw.utf8))) ?? [:]
    }

    private var items: [PatchLibraryItem] {
        let assignments = gameAssignments
        return store.items.filter { assignments[$0.id.uuidString] == game.id }
    }

    private var displayedItems: [PatchLibraryItem] {
        guard let selectedContainerID else { return items }
        let assignments = containerAssignments
        return items.filter { assignments[$0.id.uuidString] == selectedContainerID }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            TechBackground()

            VStack(spacing: 0) {
                customNavBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        headerCard
                        containerTabBar
                            .transition(.opacity)
                        featureTabSelector
                        featureContent
                        if !game.bundleID.isEmpty {
                            openGameButton
                        }
                        if currentContainerVideoUrl != nil {
                            videoTutorialButton
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                    .animation(.easeInOut(duration: 0.22), value: containers.isEmpty)
                    .animation(.easeInOut(duration: 0.2), value: selectedContainerID)
                    .animation(.easeInOut(duration: 0.18), value: selectedFeatureTab)
                }
                .refreshable {
                    async let syncTask: () = sync()
                    async let containersTask: () = loadContainers()
                    _ = await (syncTask, containersTask)
                    await loadProjectStates()
                }
            }
        }
        .toolbarHidden15()
        .task {
            async let syncTask: () = sync()
            async let containersTask: () = loadContainers()
            async let noticeTask: () = fetchNotice()
            _ = await (syncTask, containersTask, noticeTask)
            await loadProjectStates()
        }
        .sheet(item: $gameNotice) { notice in
            GameNoticeSheetView(notice: notice, onContinue: { gameNotice = nil })
        }
        .sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { _ in
            PatchUnlockView(store: store)
        }
        .sheet(isPresented: $showVideoSheet) {
            if let urlStr = currentContainerVideoUrl, let url = URL(string: urlStr) {
                VideoWebSheet(url: url)
            }
        }
        .patchAlert($store.alert, language: language)
        .toast($toast)
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

            Text(game.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            ZStack {
                Circle()
                    .fill(Color(red: 0.04, green: 0.07, blue: 0.17).opacity(0.88))
                    .overlay(
                        Circle().strokeBorder(AppTheme.neonPurple.opacity(0.40), lineWidth: 1)
                    )
                if isSyncing {
                    ProgressView()
                        .tint(AppTheme.techGlow)
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.neonPurple.opacity(0.75))
                }
            }
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Header Card (compact horizontal)

    private var headerCard: some View {
        HStack(spacing: 14) {
            // Game icon (compact)
            ZStack(alignment: .topLeading) {
                gameIconView
                    .frame(width: 58, height: 58)
                    .clipShape(CutShape(cut: 15))
                    .overlay(
                        CutShape(cut: 15)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AppTheme.techGlow.opacity(0.70), AppTheme.neonPurple.opacity(0.55)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: AppTheme.neonPurple.opacity(0.30), radius: 10)

                // HOT badge on icon
                Text("HOT")
                    .font(.system(size: 8.5, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.32, blue: 0.08), Color(red: 1.0, green: 0.10, blue: 0.0)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .offset(x: -4, y: -6)
            }

            // Name + status
            VStack(alignment: .leading, spacing: 6) {
                Text(game.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.18, green: 0.88, blue: 0.42))
                    Text("\u{0110}\u{00E3} s\u{1EB5}n s\u{00E0}ng")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.18, green: 0.88, blue: 0.42))
                }
            }

            Spacer()

            // Arrow button
            ZStack {
                Circle()
                    .fill(AppTheme.techGlow.opacity(0.14))
                    .overlay(Circle().strokeBorder(AppTheme.techGlow.opacity(0.45), lineWidth: 1))
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.techGlow)
            }
            .frame(width: 36, height: 36)
            .shadow(color: AppTheme.techGlow.opacity(0.25), radius: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Color(red: 0.05, green: 0.08, blue: 0.18).opacity(0.92)
                LinearGradient(
                    colors: [AppTheme.neonPurple.opacity(0.06), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(CutShape(cut: 20))
        .overlay(
            CutShape(cut: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.techGlow.opacity(0.50), AppTheme.neonPurple.opacity(0.35)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.neonPurple.opacity(0.12), radius: 16, y: 4)
    }

    @ViewBuilder
    private var gameIconView: some View {
        if let url = game.iconURL {
            CachedAsyncImage(url: url) { gameIconPlaceholder }
        } else {
            gameIconPlaceholder
        }
    }

    private var gameIconPlaceholder: some View {
        ZStack {
            AppTheme.resolvedBannerColor(game.bannerColor)
            Image(systemName: "app.fill")
                .resizable().scaledToFit()
                .padding(14)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Container Tab Bar

    @ViewBuilder
    private var containerTabBar: some View {
        if !containers.isEmpty {
            HStack(spacing: 0) {
                ForEach(containers) { container in
                    containerTabButton(container)
                }
            }
            .padding(5)
            .background(
                Color(red: 0.04, green: 0.07, blue: 0.16).opacity(0.88),
                in: CutShape(cut: 20)
            )
            .overlay(
                CutShape(cut: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [AppTheme.techGlow.opacity(0.40), AppTheme.neonPurple.opacity(0.30)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: AppTheme.neonPurple.opacity(0.12), radius: 16, y: 4)
        }
    }

    private func containerTabButton(_ container: RemoteContainerSummary) -> some View {
        let isSelected = selectedContainerID == container.id
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                selectedContainerID = container.id
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: container.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(container.name)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    CutShape(cut: 15)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.techGlow.opacity(0.26), AppTheme.neonPurple.opacity(0.22)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .overlay(
                            CutShape(cut: 15)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [AppTheme.techGlow, AppTheme.neonPurple],
                                        startPoint: .leading, endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: AppTheme.neonPurple.opacity(0.35), radius: 10, y: 2)
                }
            }
            .foregroundStyle(
                isSelected
                    ? AnyShapeStyle(Color.white)
                    : AnyShapeStyle(Color(red: 0.45, green: 0.55, blue: 0.72))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feature Tab Selector ("T�nh nang nhanh" | "Th�ng tin")

    private var featureTabSelector: some View {
        HStack(spacing: 0) {
            featureTabPill(title: "T\u{00ED}nh n\u{0103}ng nhanh", index: 0)
            featureTabPill(title: "Th\u{00F4}ng tin", index: 1)
        }
        .padding(4)
        .background(
            Color(red: 0.04, green: 0.06, blue: 0.15).opacity(0.92),
            in: CutShape(cut: 18)
        )
        .overlay(
            CutShape(cut: 18)
                .strokeBorder(AppTheme.neonPurple.opacity(0.20), lineWidth: 1)
        )
    }

    private func featureTabPill(title: String, index: Int) -> some View {
        let isSelected = selectedFeatureTab == index
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) {
                selectedFeatureTab = index
            }
        } label: {
            Text(title)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(isSelected ? .white : Color(red: 0.45, green: 0.55, blue: 0.72))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        CutShape(cut: 14)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.neonPurple.opacity(0.70), AppTheme.techGlow.opacity(0.55)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .shadow(color: AppTheme.neonPurple.opacity(0.40), radius: 8, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feature Content (tab body)

    @ViewBuilder
    private var featureContent: some View {
        if selectedFeatureTab == 0 {
            featureGrid
        } else {
            infoTab
        }
    }

    // MARK: - Feature Grid (2-column)

    private let gridIcons = ["bolt.fill", "cube", "scope", "person.fill", "hare.fill", "figure.run", "eye.fill", "target", "waveform", "shield.fill"]

    private var featureGrid: some View {
        Group {
            if !containersLoaded {
                loadingPlaceholder
            } else if displayedItems.isEmpty {
                emptyState
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
                        featureCard(item, colorIndex: index)
                    }
                }
                .onAppear {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        borderRotation = 360
                    }
                }
            }
        }
    }

    private func featureCard(_ item: PatchLibraryItem, colorIndex: Int) -> some View {
        let isOn = projectStates[item.id] ?? false
        let isToggling = togglingProjectID == item.id
        let rowColor = AppTheme.rowColor(colorIndex)
        let iconName = gridIcons[colorIndex % gridIcons.count]
        let binding = projectToggleBinding(for: item)
        let rules = item.project?.rules ?? []
        let toggleableCount = rules.filter(\.hasReplacement).count

        return Button {
            if !item.isLocked && toggleableCount > 0 && !isToggling {
                binding.wrappedValue.toggle()
            } else if item.isLocked {
                store.requestUnlock(for: item)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Icon + status row
                HStack(alignment: .top) {
                    // Feature icon
                    ZStack {
                        CutShape(cut: 12)
                            .fill(rowColor.opacity(isOn ? 0.22 : 0.10))
                            .overlay(
                                CutShape(cut: 12)
                                    .strokeBorder(rowColor.opacity(isOn ? 0.65 : 0.30), lineWidth: 1)
                            )
                            .shadow(color: rowColor.opacity(isOn ? 0.35 : 0.0), radius: 8)
                        if isToggling {
                            ProgressView()
                                .tint(rowColor)
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: item.isLocked ? "lock.fill" : iconName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(isOn ? rowColor : rowColor.opacity(0.55))
                        }
                    }
                    .frame(width: 46, height: 46)

                    Spacer()

                    // On/Off indicator dot
                    Circle()
                        .fill(isOn ? Color(red: 0.18, green: 0.88, blue: 0.42) : Color(red: 0.30, green: 0.35, blue: 0.48))
                        .frame(width: 8, height: 8)
                        .shadow(color: isOn ? Color(red: 0.18, green: 0.88, blue: 0.42).opacity(0.70) : .clear, radius: 4)
                        .padding(.top, 4)
                }
                .padding(.bottom, 10)

                // Feature name
                Text(displayName(for: item))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 6)

                // Status label
                HStack(spacing: 4) {
                    if isOn {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.18, green: 0.88, blue: 0.42))
                        Text("\u{0110}\u{00E3} b\u{1EAD}t")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.18, green: 0.88, blue: 0.42))
                    } else {
                        Circle()
                            .fill(Color(red: 0.35, green: 0.40, blue: 0.55))
                            .frame(width: 8, height: 8)
                        Text("T\u{1EAF}t")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(red: 0.45, green: 0.52, blue: 0.68))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Color(red: 0.05, green: 0.07, blue: 0.16).opacity(0.90)
                    if isOn {
                        LinearGradient(
                            colors: [rowColor.opacity(0.10), .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .clipShape(CutShape(cut: 18))
            .overlay(
                CutShape(cut: 18)
                    .strokeBorder(
                        isOn
                            ? LinearGradient(colors: [rowColor.opacity(0.70), rowColor.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [AppTheme.techGlow.opacity(0.22), AppTheme.neonPurple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .overlay(
                CutShape(cut: 18)
                    .stroke(
                        AngularGradient(
                            colors: [
                                .clear,
                                AppTheme.techGlow.opacity(0.0),
                                AppTheme.techGlow.opacity(0.90),
                                AppTheme.neonPurple.opacity(0.95),
                                AppTheme.techGlow.opacity(0.90),
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
            .shadow(color: isOn ? rowColor.opacity(0.20) : AppTheme.neonPurple.opacity(0.06), radius: 10, y: 3)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.95))
        .animation(.easeInOut(duration: 0.18), value: isOn)
    }

    // MARK: - Info Tab

    private var infoTab: some View {
        VStack(spacing: 0) {
            infoRow(label: "Bundle ID", value: game.bundleID.isEmpty ? "�" : game.bundleID)
            Divider().overlay(AppTheme.techGlow.opacity(0.15)).padding(.horizontal, 16)
            infoRow(label: "S\u{1ED1} t\u{00ED}nh n\u{0103}ng", value: "\(displayedItems.count)")
            if let gameType = game.type, !gameType.isEmpty {
                Divider().overlay(AppTheme.techGlow.opacity(0.15)).padding(.horizontal, 16)
                infoRow(label: "Lo\u{1EA1}i", value: gameType.uppercased())
            }
        }
        .background(Color(red: 0.05, green: 0.07, blue: 0.16).opacity(0.90))
        .clipShape(CutShape(cut: 20))
        .overlay(
            CutShape(cut: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.techGlow.opacity(0.35), AppTheme.neonPurple.opacity(0.22)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.46, green: 0.56, blue: 0.72))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - Open Game Button

    private var openGameButton: some View {
        Button {
            AppLauncherOpenBundleID(game.bundleID)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rocket.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(game.type == "app" ? "M\u{1EDF} \u{1EE9}ng d\u{1EE5}ng ngay" : language.text("patch.open_game_now"))
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 19)
            .background(
                LinearGradient(
                    colors: [AppTheme.neonPurple, Color(red: 0.40, green: 0.18, blue: 0.85), AppTheme.techGlow.opacity(0.70)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: CutShape(cut: 18)
            )
            .shadow(color: AppTheme.neonPurple.opacity(0.55), radius: 16, x: -4, y: 8)
            .shadow(color: AppTheme.techGlow.opacity(0.35), radius: 16, x: 4, y: 8)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var videoTutorialButton: some View {
        Button {
            showVideoSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(language.text("patch.watch_tutorial"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(AppTheme.techGlow)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(.ultraThinMaterial, in: CutShape(cut: 18))
            .overlay(
                CutShape(cut: 18)
                    .strokeBorder(AppTheme.techGlow.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: AppTheme.techGlow.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Helper Views

    private var loadingPlaceholder: some View {
        VStack {
            ProgressView().tint(AppTheme.techGlow)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if isSyncing {
                ProgressView().tint(AppTheme.techGlow)
            } else {
                Image(systemName: "shippingbox")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(AppTheme.neonPurple)
                Text(language.text("patch.empty_title"))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(language.text("patch.game_empty_message"))
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.46, green: 0.56, blue: 0.72))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    // MARK: - Bindings & Logic (unchanged)

    private func projectToggleBinding(for item: PatchLibraryItem) -> Binding<Bool> {
        Binding(
            get: { projectStates[item.id] ?? false },
            set: { setProjectState($0, item: item) }
        )
    }

    private func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let remoteItems = try? await PatchHubService.fetchPatches() else { return }
        let remoteForGame = remoteItems.filter { $0.gameId == game.id }
        let remoteIDsForGame = Set(remoteForGame.map(\.id))

        var imported = importedOnlineIDs
        var assignments = gameAssignments
        var remoteMap = remoteToLocalMap
        var names = remoteDisplayNames
        var containerAssign = containerAssignments
        var didChange = false

        for (serverID, localID) in remoteMap where assignments[localID] == game.id && !remoteIDsForGame.contains(serverID) {
            if let localUUID = UUID(uuidString: localID),
               let staleItem = store.items.first(where: { $0.id == localUUID }) {
                store.delete(staleItem)
            }
            assignments.removeValue(forKey: localID)
            remoteMap.removeValue(forKey: serverID)
            names.removeValue(forKey: localID)
            containerAssign.removeValue(forKey: localID)
            imported.remove(serverID)
            didChange = true
        }

        for item in remoteForGame {
            guard let localID = remoteMap[item.id],
                  let localUUID = UUID(uuidString: localID),
                  !store.items.contains(where: { $0.id == localUUID }) else { continue }
            imported.remove(item.id)
            assignments.removeValue(forKey: localID)
            remoteMap.removeValue(forKey: item.id)
            names.removeValue(forKey: localID)
            containerAssign.removeValue(forKey: localID)
            didChange = true
        }

        let pending = remoteForGame.filter { !imported.contains($0.id) }
        for item in pending {
            do {
                let fileURL = try await PatchHubService.downloadPatch(item)
                let packageIDString: String? = await Task.detached(priority: .utility) {
                    do {
                        let data = try PatchProjectLibrary.readPackage(at: fileURL)
                        let summary = try PatchPackageCodec.inspect(data)
                        _ = try PatchProjectLibrary.save(data: data, projectName: item.name)
                        try? FileManager.default.removeItem(at: fileURL)
                        if let password = item.password, !password.isEmpty {
                            if let decoded = try? PatchPackageCodec.decode(data, password: password) {
                                try? PatchKeyStore.store(decoded.contentKey, for: summary)
                            }
                        }
                        return summary.packageID.uuidString
                    } catch {
                        return nil
                    }
                }.value
                if let packageIDString {
                    imported.insert(item.id)
                    assignments[packageIDString] = game.id
                    remoteMap[item.id] = packageIDString
                    names[packageIDString] = item.name
                    if let containerId = item.containerId {
                        containerAssign[packageIDString] = containerId
                    } else {
                        containerAssign.removeValue(forKey: packageIDString)
                    }
                    didChange = true
                }
            } catch {
                continue
            }
        }

        for item in remoteForGame {
            guard let localID = remoteMap[item.id] else { continue }
            if names[localID] != item.name {
                names[localID] = item.name
            }
            if let containerId = item.containerId {
                containerAssign[localID] = containerId
            } else {
                containerAssign.removeValue(forKey: localID)
            }
            if let password = item.password, !password.isEmpty,
               let localUUID = UUID(uuidString: localID),
               let localItem = store.items.first(where: { $0.id == localUUID }),
               localItem.isLocked {
                await Task.detached(priority: .utility) {
                    guard let data = try? PatchProjectLibrary.readPackage(at: localItem.packageURL),
                          let summary = try? PatchPackageCodec.inspect(data),
                          let decoded = try? PatchPackageCodec.decode(data, password: password) else { return }
                    try? PatchKeyStore.store(decoded.contentKey, for: summary)
                }.value
                didChange = true
            }
        }

        importedOnlineIDsRaw = imported.joined(separator: ",")
        if let encoded = try? JSONEncoder().encode(assignments), let json = String(data: encoded, encoding: .utf8) {
            gameAssignmentsRaw = json
        }
        if let encoded = try? JSONEncoder().encode(remoteMap), let json = String(data: encoded, encoding: .utf8) {
            remoteToLocalMapRaw = json
        }
        if let encoded = try? JSONEncoder().encode(names), let json = String(data: encoded, encoding: .utf8) {
            remoteDisplayNamesRaw = json
        }
        if let encoded = try? JSONEncoder().encode(containerAssign), let json = String(data: encoded, encoding: .utf8) {
            containerAssignmentsRaw = json
        }
        if didChange {
            store.reload()
        }
    }

    private func fetchNotice() async {
        let notices = await PatchHubService.fetchGameNotices()
        if let notice = notices[game.id] {
            await MainActor.run { gameNotice = notice }
        }
    }

    private func loadContainers() async {
        defer { containersLoaded = true }
        guard let fetched = try? await PatchHubService.fetchContainers() else {
            containers = []
            selectedContainerID = nil
            return
        }
        let forGame = fetched.filter { $0.gameId == game.id }.sorted { $0.order < $1.order }
        containers = forGame
        if let selectedContainerID, forGame.contains(where: { $0.id == selectedContainerID }) {
            return
        }
        selectedContainerID = forGame.first?.id
    }

    private func loadProjectStates() async {
        let currentItems = items
        guard !currentItems.isEmpty else { return }
        let states: [UUID: Bool] = await Task.detached(priority: .userInitiated) {
            var result: [UUID: Bool] = [:]
            for item in currentItems {
                let applicable = (item.project?.rules ?? []).filter(\.hasReplacement)
                guard !applicable.isEmpty else { continue }
                let allOn = applicable.allSatisfy { DevicePatchService.currentRuleState(for: $0) == true }
                result[item.id] = allOn
            }
            return result
        }.value
        projectStates = states
    }

    private func setProjectState(_ isOn: Bool, item: PatchLibraryItem) {
        guard let project = item.project else { return }
        let applicable = project.rules.filter(\.hasReplacement)
        guard !applicable.isEmpty, togglingProjectID == nil else { return }

        let useSetRuleState = applicable.allSatisfy(\.canToggle)

        togglingProjectID = item.id
        Task.detached(priority: .userInitiated) {
            if isOn {
                guard await PatchHubService.verifyAccess(licenseKey: licenseGate.storedKeyCode) else {
                    await MainActor.run {
                        togglingProjectID = nil
                        projectStates[item.id] = false
                        toast = ToastMessage(text: "X�c th?c key th?t b?i. Vui l�ng th? l?i.", style: .error)
                    }
                    return
                }
            }
            var failure: PatchPackageError?
            if useSetRuleState {
                for rule in applicable {
                    do {
                        try DevicePatchService.setRuleState(isOn, rule: rule)
                    } catch let e as PatchPackageError { failure = e
                    } catch { failure = .applyFailed }
                }
            } else {
                do {
                    if isOn {
                        _ = try DevicePatchService.apply(project: project)
                    } else if let receipt = DevicePatchService.latestReceipt(projectID: project.id) {
                        try DevicePatchService.restore(receipt: receipt)
                    } else {
                        throw PatchPackageError.restoreFailed
                    }
                } catch let e as PatchPackageError { failure = e
                } catch { failure = .applyFailed }
            }

            let actualState = applicable.allSatisfy { DevicePatchService.currentRuleState(for: $0) == true }
            let capturedFailure = failure
            await MainActor.run {
                togglingProjectID = nil
                projectStates[item.id] = actualState
                if let failure = capturedFailure {
                    store.alert = .failure(
                        appState: appState,
                        fallbackMessageKey: failure.localizationKey,
                        fallbackArgument: failure.localizationArgument
                    )
                } else if actualState == isOn {
                    let key = isOn ? "patch.toggle_on_success" : "patch.toggle_off_success"
                    toast = ToastMessage(text: language.text(key, displayName(for: item)), style: isOn ? .success : .off)
                }
            }
        }
    }
}

// MARK: - Video Tutorial Sheet

private struct VideoWebSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            WebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("��ng") { dismiss() }
                            .foregroundStyle(AppTheme.neonPurple)
                    }
                }
        }
    }
}

private struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
