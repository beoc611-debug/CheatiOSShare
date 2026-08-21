import SwiftUI
import UIKit

// MARK: - Sort

enum AppSortOrder: Equatable {
    case nameAsc, nameDesc, sizeAsc, sizeDesc
}

// MARK: - ViewModel

final class AppsViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isLoading = false
    @Published var isResolving = false
    @Published var sizeCache: [String: Int64] = [:]
    private var hasLoaded = false

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        reload()
    }

    func reload() {
        isLoading = true
        isResolving = true
        sizeCache = [:]
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let bundleMetadata = ContainerStore.applicationBundleMetadataCatalog()
            let apiApps = ContainerStore.applyingBundleMetadata(
                to: ContainerStore.installedAppsFromAPI(),
                catalog: bundleMetadata
            )
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
            result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            let preliminary = result.filter { ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID) }
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
            let mhaApps = ContainerStore.installedAppsFromMHACandidates(
                identifiers: mhaIdentifiers,
                bundleMetadata: bundleMetadata
            ) { [weak self] discoveredApps in
                guard let self else { return }
                var progressive = AppDataCatalogMerger.merge(
                    identified: discoveredApps + baseIdentifiedApps,
                    fallback: [],
                    identifier: { $0.bundleID },
                    path: { $0.containerPath }
                )
                progressive = progressive.filter { ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID) }
                progressive.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                DispatchQueue.main.async { [weak self] in self?.apps = progressive }
            }

            let allKnownApps = mhaApps + baseIdentifiedApps
            let identifiedPaths = Set(allKnownApps.map { ContainerDiscoveryMerger.canonicalPath($0.containerPath) })
            let unmatched = filesystemApps.filter {
                !identifiedPaths.contains(ContainerDiscoveryMerger.canonicalPath($0.containerPath))
            }
            let inferred = ContainerStore.inferUnidentifiedApps(
                in: unmatched, knownApps: allKnownApps,
                launchServicesIdentifiers: Set(launchServicesIdentifiers)
            ).filter { ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID) }

            result = AppDataCatalogMerger.merge(
                identified: allKnownApps, fallback: inferred,
                identifier: { $0.bundleID }, path: { $0.containerPath }
            )
            result = result.filter { ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID) }
            result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.apps = result
                self.isLoading = false
                self.isResolving = false
            }
        }
    }

    func fetchSize(for app: InstalledApp) {
        guard !app.containerPath.isEmpty, sizeCache[app.bundleID] == nil else { return }
        sizeCache[app.bundleID] = -1 // loading sentinel
        let path = app.containerPath
        let bid = app.bundleID
        DispatchQueue.global(qos: .background).async { [weak self] in
            var total: Int64 = 0
            if let e = FileManager.default.enumerator(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let url as URL in e {
                    total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                    if total > 50 * 1024 * 1024 * 1024 { break }
                }
            }
            DispatchQueue.main.async { [weak self] in self?.sizeCache[bid] = total }
        }
    }
}

// MARK: - AppDataBrowserView (Filza-style)

struct AppDataBrowserView: View {
    @ObservedObject var viewModel: AppsViewModel
    @Environment(\.appLanguage) private var language
    @State private var searchText = ""
    @State private var sortOrder: AppSortOrder = .nameAsc
    @State private var isEditing = false

    private var filteredApps: [InstalledApp] {
        let base: [InstalledApp]
        if searchText.isEmpty {
            base = viewModel.apps
        } else {
            let q = searchText.lowercased()
            base = viewModel.apps.filter {
                $0.displayName.lowercased().contains(q) || $0.bundleID.lowercased().contains(q)
            }
        }
        switch sortOrder {
        case .nameAsc:  return base
        case .nameDesc: return base.reversed()
        case .sizeAsc:
            return base.sorted {
                (viewModel.sizeCache[$0.bundleID] ?? 0) < (viewModel.sizeCache[$1.bundleID] ?? 0)
            }
        case .sizeDesc:
            return base.sorted {
                (viewModel.sizeCache[$0.bundleID] ?? 0) > (viewModel.sizeCache[$1.bundleID] ?? 0)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sortBar
            Divider().background(Color.white.opacity(0.08))
            appListContent
        }
        .background(Color(red: 0.047, green: 0.063, blue: 0.118))
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: language.text("applist.search_prompt")
        )
        .navigationBarItems(trailing: Button(isEditing ? "Xong" : "Sửa") {
            isEditing.toggle()
        }.foregroundStyle(AppTheme.neonPurple))
        .onAppear { viewModel.loadIfNeeded() }
    }

    // MARK: - Sort bar (matches Filza layout)

    private var sortBar: some View {
        HStack(spacing: 0) {
            // Search icon (matches Filza left icon)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.50, green: 0.58, blue: 0.75))
                .frame(width: 44)

            // Tên column sort
            Button {
                if sortOrder == .nameAsc { sortOrder = .nameDesc }
                else { sortOrder = .nameAsc }
            } label: {
                HStack(spacing: 4) {
                    Text("Tên")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(sortOrder == .nameAsc || sortOrder == .nameDesc
                            ? AppTheme.neonPurple : Color(red: 0.55, green: 0.62, blue: 0.78))
                    Image(systemName: sortOrder == .nameDesc ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(sortOrder == .nameAsc || sortOrder == .nameDesc
                            ? AppTheme.neonPurple : Color(red: 0.55, green: 0.62, blue: 0.78))
                        .opacity(sortOrder == .nameAsc || sortOrder == .nameDesc ? 1 : 0.4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Kích thước column sort
            Button {
                if sortOrder == .sizeDesc { sortOrder = .sizeAsc }
                else { sortOrder = .sizeDesc }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: sortOrder == .sizeAsc ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(sortOrder == .sizeAsc || sortOrder == .sizeDesc
                            ? AppTheme.neonPurple : Color(red: 0.55, green: 0.62, blue: 0.78))
                        .opacity(sortOrder == .sizeAsc || sortOrder == .sizeDesc ? 1 : 0.4)
                    Text("Kích thước")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(sortOrder == .sizeAsc || sortOrder == .sizeDesc
                            ? AppTheme.neonPurple : Color(red: 0.55, green: 0.62, blue: 0.78))
                }
            }
            .frame(width: 110, alignment: .trailing)

            // Grid/list toggle (decorative, matches Filza)
            HStack(spacing: 6) {
                Image(systemName: "lessthan")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.50, green: 0.58, blue: 0.75))
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.50, green: 0.58, blue: 0.75))
            }
            .frame(width: 52)
        }
        .frame(height: 38)
        .padding(.horizontal, 4)
        .background(Color(red: 0.068, green: 0.090, blue: 0.155))
    }

    // MARK: - List

    @ViewBuilder
    private var appListContent: some View {
        if (viewModel.isLoading || viewModel.isResolving) && viewModel.apps.isEmpty {
            Spacer()
            VStack(spacing: 14) {
                ProgressView().tint(AppTheme.neonPurple).scaleEffect(1.2)
                Text(language.text("browser.loading"))
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
            }
            Spacer()
        } else if viewModel.apps.isEmpty {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "tray")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AppTheme.neonPurple.opacity(0.6))
                Text(language.text("browser.empty"))
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                    .multilineTextAlignment(.center)
                Button(language.text("browser.retry")) { viewModel.reload() }
                    .foregroundStyle(AppTheme.neonPurple)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    // Scanning indicator row
                    if viewModel.isResolving {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.mini).tint(AppTheme.neonCyan)
                            Text(language.text("applist.scanning"))
                                .font(.caption)
                                .foregroundStyle(AppTheme.neonCyan.opacity(0.8))
                            Spacer()
                            Text("\(filteredApps.count) ứng dụng")
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.45, green: 0.55, blue: 0.72))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.068, green: 0.090, blue: 0.155))
                        Divider().background(Color.white.opacity(0.07))
                    }

                    ForEach(filteredApps) { app in
                        FilzaAppRow(
                            app: app,
                            cachedSize: viewModel.sizeCache[app.bundleID]
                        )
                        .onAppear { viewModel.fetchSize(for: app) }

                        Divider()
                            .background(Color.white.opacity(0.07))
                            .padding(.leading, 72)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Filza-style row

private struct FilzaAppRow: View {
    let app: InstalledApp
    let cachedSize: Int64?      // nil=not fetched, -1=loading, 0+=done

    private var sizeText: String {
        guard let s = cachedSize, s >= 0 else { return "" }
        return ByteCountFormatter.string(fromByteCount: s, countStyle: .file)
    }

    var body: some View {
        NavigationLink(destination: AppDetailView(app: app)) {
            HStack(spacing: 12) {
                BrowserAppIcon(app: app, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if app.displayName != app.bundleID {
                        Text(app.bundleID)
                            .font(.caption2.monospaced())
                            .foregroundStyle(Color(red: 0.48, green: 0.57, blue: 0.74))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 8)

                // Size column
                Group {
                    if cachedSize == -1 {
                        ProgressView().controlSize(.mini).tint(Color(red: 0.48, green: 0.57, blue: 0.74))
                    } else if !sizeText.isEmpty {
                        Text(sizeText)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Color(red: 0.55, green: 0.64, blue: 0.80))
                    }
                }
                .frame(width: 80, alignment: .trailing)

                // ⓘ info button (navigates same destination via NavigationLink)
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppTheme.techGlow)
                    .frame(width: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(red: 0.047, green: 0.063, blue: 0.118))
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
                DispatchQueue.main.async { resolvedIcon = icon }
            }
        }
    }
}
