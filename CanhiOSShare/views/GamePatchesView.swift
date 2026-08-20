import SwiftUI

struct GamePatchesView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let game: RemoteGameSummary
    @ObservedObject var store: PatchProjectStore

    @State private var isSyncing = false
    @State private var projectStates: [UUID: Bool] = [:]
    @State private var togglingProjectID: UUID?
    @State private var toast: ToastMessage?
    @State private var containers: [RemoteContainerSummary] = []
    @State private var selectedContainerID: String?
    @State private var containersLoaded = false
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

                ScrollView {
                    VStack(spacing: 16) {
                        header
                        containerTabBar
                            .transition(.opacity)
                        menuCard
                        if !game.bundleID.isEmpty {
                            openGameButton
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 32)
                    .animation(.easeInOut(duration: 0.22), value: containers.isEmpty)
                    .animation(.easeInOut(duration: 0.2), value: selectedContainerID)
                }
                .refreshable {
                    async let syncTask: () = sync()
                    async let containersTask: () = loadContainers()
                    _ = await (syncTask, containersTask)
                    await loadProjectStates()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            async let syncTask: () = sync()
            async let containersTask: () = loadContainers()
            _ = await (syncTask, containersTask)
            await loadProjectStates()
        }
        .sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { _ in
            PatchUnlockView(store: store)
        }
        .alert(item: $store.alert) { alert in
            Alert(
                title: Text(language.text(alert.titleKey)),
                message: Text(alert.message(language: language)),
                dismissButton: .default(Text(language.text("common.ok")))
            )
        }
        .toast($toast)
    }

    // MARK: - Custom Nav Bar

    private var customNavBar: some View {
        HStack(spacing: 0) {
            // Circular back button
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

            // Balance — same width as back button; shows spinner while syncing
            ZStack {
                if isSyncing {
                    ProgressView()
                        .tint(AppTheme.techGlow)
                        .scaleEffect(0.85)
                }
            }
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Header (icon + name + bundle ID)

    private var header: some View {
        VStack(spacing: 14) {
            // Game icon with premium layered glow
            ZStack {
                // Blue outer glow
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(AppTheme.techGlow.opacity(0.14))
                    .frame(width: 140, height: 140)
                    .blur(radius: 22)

                // Purple accent glow (lower-right)
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(AppTheme.neonPurple.opacity(0.10))
                    .frame(width: 138, height: 138)
                    .blur(radius: 14)
                    .offset(x: 8, y: 8)

                // Icon clipped in rounded square
                gameIconView
                    .frame(width: 118, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 27, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AppTheme.techGlow.opacity(0.75), AppTheme.neonPurple.opacity(0.55)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            }

            VStack(spacing: 7) {
                Text(game.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if !game.bundleID.isEmpty {
                    Text(game.bundleID)
                        .font(.system(size: 13).monospaced())
                        .foregroundStyle(Color(red: 0.46, green: 0.56, blue: 0.72))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 8)
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
                .padding(22)
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
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.techGlow.opacity(0.26), AppTheme.neonPurple.opacity(0.22)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
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

    // MARK: - Menu Card

    private var menuCard: some View {
        VStack(spacing: 0) {
            menuHeader

            Group {
                if !containersLoaded {
                    loadingPlaceholder
                } else if displayedItems.isEmpty {
                    emptyState
                } else if displayedItems.count > Self.maxVisibleRows {
                    ScrollView(showsIndicators: false) {
                        rowsList
                    }
                    .frame(height: Self.rowHeight * CGFloat(Self.maxVisibleRows))
                } else {
                    rowsList
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        }
        .background(Color(red: 0.030, green: 0.050, blue: 0.115).opacity(0.82))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            AppTheme.techGlow.opacity(0.55),
                            AppTheme.neonPurple.opacity(0.38),
                            AppTheme.techGlow.opacity(0.18)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.techGlow.opacity(0.10), radius: 24, y: 6)
        .shadow(color: AppTheme.neonPurple.opacity(0.08), radius: 16, y: 4)
        .animation(.easeInOut(duration: 0.22), value: containersLoaded)
    }

    private var menuHeader: some View {
        HStack(spacing: 10) {
            // Cyan neon vertical bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.neonCyan, AppTheme.techGlow],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 3, height: 20)
                .shadow(color: AppTheme.neonCyan.opacity(0.80), radius: 6)

            // Purple bolt
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.neonPurple)

            Text(language.text("patch.menu_title"))
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .textCase(.uppercase)
                .tracking(0.6)

            Spacer()

            if isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(AppTheme.techGlow)
            } else {
                // AUTO pill
                Text(language.text("patch.menu_auto_badge"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.neonCyan)
                    .tracking(0.5)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        Color(red: 0.04, green: 0.16, blue: 0.26).opacity(0.90),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule().strokeBorder(AppTheme.neonCyan.opacity(0.65), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.neonCyan.opacity(0.30), radius: 6)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            // Subtle neon separator line under header
            LinearGradient(
                colors: [AppTheme.techGlow.opacity(0.22), AppTheme.neonPurple.opacity(0.14)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 1)
        }
    }

    // MARK: - Rows

    private static let rowHeight: CGFloat = 70
    private static let maxVisibleRows = 5

    private var rowsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
                itemRow(item, colorIndex: index)
                    .transition(
                        .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.94, anchor: .top))
                    )
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.78).delay(Double(index) * 0.045),
                        value: selectedContainerID
                    )
                if item.id != displayedItems.last?.id {
                    // Subtle blue-gray 1px separator
                    Rectangle()
                        .fill(Color(red: 0.18, green: 0.26, blue: 0.44).opacity(0.30))
                        .frame(height: 1)
                        .padding(.horizontal, 18)
                }
            }
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func itemRow(_ item: PatchLibraryItem, colorIndex: Int) -> some View {
        if item.isLocked {
            Button { store.requestUnlock(for: item) } label: {
                PatchProjectRow(item: item, language: language)
            }
            .buttonStyle(.plain)
        } else {
            toggleRow(item, colorIndex: colorIndex)
        }
    }

    private func toggleRow(_ item: PatchLibraryItem, colorIndex: Int) -> some View {
        let rules = item.project?.rules ?? []
        let toggleableCount = rules.filter(\.hasReplacement).count
        let rowColor = AppTheme.rowColor(colorIndex)

        return HStack(spacing: 14) {
            // Glass icon container with colored border + glow
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(rowColor.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(rowColor.opacity(0.48), lineWidth: 1)
                    )
                    .shadow(color: rowColor.opacity(0.28), radius: 8)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(rowColor)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName(for: item))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(language.text("patch.rules_count", Int64(rules.count)))
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.46, green: 0.56, blue: 0.72))
            }

            Spacer()

            if togglingProjectID == item.id {
                ProgressView()
                    .tint(AppTheme.techGlow)
            } else {
                Toggle("", isOn: projectToggleBinding(for: item))
                    .labelsHidden()
                    .tint(AppTheme.neonPurple)
                    .disabled(toggleableCount == 0)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    // MARK: - Open Game Button

    private var openGameButton: some View {
        Button {
            AppLauncherOpenBundleID(game.bundleID)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(language.text("patch.open_game_now"))
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 19)
            .background(
                LinearGradient(
                    colors: [AppTheme.techGlow, AppTheme.neonPurple],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: AppTheme.techGlow.opacity(0.50), radius: 16, x: -4, y: 8)
            .shadow(color: AppTheme.neonPurple.opacity(0.40), radius: 16, x: 4, y: 8)
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
                guard await PatchHubService.verifyAccess() else {
                    await MainActor.run {
                        togglingProjectID = nil
                        projectStates[item.id] = false
                        toast = ToastMessage(text: "Xác thực key thất bại. Vui lòng thử lại.")
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
            await MainActor.run {
                togglingProjectID = nil
                projectStates[item.id] = actualState
                if let failure {
                    store.alert = .failure(
                        appState: appState,
                        fallbackMessageKey: failure.localizationKey,
                        fallbackArgument: failure.localizationArgument
                    )
                } else if actualState == isOn {
                    let key = isOn ? "patch.toggle_on_success" : "patch.toggle_off_success"
                    toast = ToastMessage(text: language.text(key, displayName(for: item)))
                }
            }
        }
    }
}
