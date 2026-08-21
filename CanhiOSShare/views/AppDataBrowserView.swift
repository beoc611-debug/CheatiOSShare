import SwiftUI
import UIKit

// MARK: - ViewModel (held by GamesHomeView as @StateObject so state persists across tab switches)

final class AppsViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isLoading = false
    @Published var isResolving = false
    private var hasLoaded = false

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        reload()
    }

    func reload() {
        isLoading = true
        isResolving = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let bundleMetadata = ContainerStore.applicationBundleMetadataCatalog()
            let apiApps = ContainerStore.applyingBundleMetadata(
                to: ContainerStore.installedAppsFromAPI(),
                catalog: bundleMetadata
            )
            if apiApps.isEmpty {
                log("browser: installed-app API unavailable; trying MCM class-2 enumeration...")
            }
            let apiSet = Set(apiApps.map { $0.bundleID })

            let dynamicIdentifiers = ContainerStore.dynamicAppIdentifiers()
            let mcmApps = ContainerStore.installedAppsFromMCM(
                identifiers: dynamicIdentifiers,
                bundleMetadata: bundleMetadata
            )
            let filesystemApps = ContainerStore.containersFromFilesystem()
            let baseIdentifiedApps = mcmApps + apiApps
            var result = ContainerDiscoveryMerger.merge(
                enumerated: filesystemApps,
                identified: baseIdentifiedApps,
                path: { $0.containerPath }
            )
            log("browser: merged api=\(apiApps.count), MCM=\(mcmApps.count), filesystem=\(filesystemApps.count) -> \(result.count)")
            result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            let preliminary = result.filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID) &&
                AppsViewModel.isUserApp($0, apiSet: apiSet)
            }
            DispatchQueue.main.async { [weak self] in
                self?.apps = preliminary
                self?.isLoading = false
            }

            let launchServicesIdentifiers = ContainerStore.launchServicesStoreIdentifiers()
            let mhaIdentifiers = MHAIdentifierCatalog.identifiers(
                dynamic: dynamicIdentifiers,
                installed: apiApps.map(\.bundleID),
                research: ContainerStore.researchAppIdentifiers,
                custom: bundleMetadata.keys.sorted(),
                launchServices: launchServicesIdentifiers
            )
            log(
                "browser: MHA catalog dynamic=\(dynamicIdentifiers.count), " +
                "installed=\(apiApps.count), research=\(ContainerStore.researchAppIdentifiers.count), " +
                "LaunchServices=\(launchServicesIdentifiers.count) -> \(mhaIdentifiers.count) candidates"
            )
            let mhaApps = ContainerStore.installedAppsFromMHACandidates(
                identifiers: mhaIdentifiers,
                bundleMetadata: bundleMetadata
            ) { [weak self] discoveredApps in
                guard let self else { return }
                var progressiveResult = AppDataCatalogMerger.merge(
                    identified: discoveredApps + baseIdentifiedApps,
                    fallback: [],
                    identifier: { $0.bundleID },
                    path: { $0.containerPath }
                )
                progressiveResult = progressiveResult.filter {
                    ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID) &&
                    AppsViewModel.isUserApp($0, apiSet: apiSet)
                }
                progressiveResult.sort {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                DispatchQueue.main.async { [weak self] in
                    self?.apps = progressiveResult
                }
            }

            let allKnownApps = mhaApps + baseIdentifiedApps
            let identifiedPaths = Set(allKnownApps.map {
                ContainerDiscoveryMerger.canonicalPath($0.containerPath)
            })
            let unmatchedFilesystemApps = filesystemApps.filter {
                !identifiedPaths.contains(
                    ContainerDiscoveryMerger.canonicalPath($0.containerPath)
                )
            }
            let inferredFilesystemApps = ContainerStore.inferUnidentifiedApps(
                in: unmatchedFilesystemApps,
                knownApps: allKnownApps,
                launchServicesIdentifiers: Set(launchServicesIdentifiers)
            ).filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID) &&
                AppsViewModel.isUserApp($0, apiSet: apiSet)
            }
            result = AppDataCatalogMerger.merge(
                identified: allKnownApps,
                fallback: inferredFilesystemApps,
                identifier: { $0.bundleID },
                path: { $0.containerPath }
            )
            result = result.filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID) &&
                AppsViewModel.isUserApp($0, apiSet: apiSet)
            }
            result.sort {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.apps = result
                self.isLoading = false
                self.isResolving = false
            }
        }
    }

    private static func isUserApp(_ app: InstalledApp, apiSet: Set<String>) -> Bool {
        if apiSet.contains(app.bundleID) { return true }
        return !app.name.isEmpty && app.name != app.bundleID
    }
}

// MARK: - View

struct AppDataBrowserView: View {
    @ObservedObject var viewModel: AppsViewModel
    @Environment(\.appLanguage) private var language
    @State private var searchText = ""

    private var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return viewModel.apps }
        let q = searchText.lowercased()
        return viewModel.apps.filter {
            $0.displayName.lowercased().contains(q) || $0.bundleID.lowercased().contains(q)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                appsSectionHeader
                    .padding(.horizontal, 20)

                appsContent
                    .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: language.text("applist.search_prompt")
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { viewModel.reload() } label: {
                    if viewModel.isResolving {
                        ProgressView().tint(AppTheme.neonPurple)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppTheme.neonPurple)
                    }
                }
                .disabled(viewModel.isResolving)
            }
        }
        .onAppear {
            viewModel.loadIfNeeded()
        }
    }

    // MARK: - Manage card

    private var manageCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.neonPurple.opacity(0.20))
                    .frame(width: 44, height: 44)
                Image(systemName: "externaldrive.badge.icloud")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppTheme.neonPurple)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(language.text("applist.manage_header"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(language.text("applist.manage_subtitle"))
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard()
    }

    // MARK: - Section header (matches "GAME HỖ TRỢ" style)

    private var appsSectionHeader: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.clear, AppTheme.neonPurple.opacity(0.45)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 1)

            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.neonCyan, AppTheme.neonPurple],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text(language.text("applist.apps_count", Int64(filteredApps.count)).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                    .tracking15(1.5)
            }

            Rectangle()
                .fill(LinearGradient(
                    colors: [AppTheme.neonPurple.opacity(0.45), Color.clear],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 1)

            if viewModel.isResolving {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini).tint(AppTheme.neonCyan)
                    Text(language.text("applist.scanning"))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.neonCyan.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Apps content

    @ViewBuilder
    private var appsContent: some View {
        if (viewModel.isLoading || viewModel.isResolving) && viewModel.apps.isEmpty {
            loadingCard
        } else if viewModel.apps.isEmpty {
            emptyCard
        } else if filteredApps.isEmpty {
            searchEmptyCard
        } else {
            VStack(spacing: 0) {
                ForEach(Array(filteredApps.enumerated()), id: \.element.id) { idx, app in
                    NavigationLink {
                        AppDetailView(app: app)
                    } label: {
                        appRow(app)
                    }
                    .buttonStyle(.plain)

                    if idx < filteredApps.count - 1 {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.clear, AppTheme.techGlow.opacity(0.15), Color.clear],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .techCard(16)
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 12) {
            BrowserAppIcon(app: app)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if !app.version.isEmpty {
                    Text("v\(app.version)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.neonCyan.opacity(0.8))
                }
                HStack(spacing: 4) {
                    if !app.containerPath.isEmpty {
                        appBadge("DATA", color: AppTheme.techGlow)
                    }
                    appBadge("IPA", color: AppTheme.neonPurple)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 0.40, green: 0.50, blue: 0.70))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func appBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - State cards

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().tint(AppTheme.neonPurple)
            Text(language.text("browser.loading"))
                .font(.caption)
                .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .techCard(16)
    }

    private var emptyCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.neonPurple.opacity(0.7))
            Text(language.text("browser.empty"))
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                .multilineTextAlignment(.center)
            Button(language.text("browser.retry")) { viewModel.reload() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.neonPurple)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .techCard(16)
    }

    private var searchEmptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(AppTheme.techGlow.opacity(0.7))
            Text(language.text("browser.search_empty"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Text(language.text("browser.search_apps_empty_message"))
                .font(.caption)
                .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .techCard(16)
    }
}

// MARK: - BrowserAppIcon

struct BrowserAppIcon: View {
    let app: InstalledApp
    var size: CGFloat = 36
    @State private var resolvedIcon: UIImage?
    @State private var didRequestIcon = false

    init(app: InstalledApp, size: CGFloat = 36) {
        self.app = app
        self.size = size
        _resolvedIcon = State(initialValue: app.icon)
    }

    var body: some View {
        Group {
            if let resolvedIcon {
                Image(uiImage: resolvedIcon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.40))
                    .foregroundStyle(AppTheme.neonPurple.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.neonPurple.opacity(0.12))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
        .onAppear {
            guard resolvedIcon == nil, !didRequestIcon else { return }
            didRequestIcon = true
            let bundleID = app.bundleID
            DispatchQueue.global(qos: .utility).async {
                let icon = iconForBundleID(bundleID)
                DispatchQueue.main.async {
                    resolvedIcon = icon
                }
            }
        }
    }
}
