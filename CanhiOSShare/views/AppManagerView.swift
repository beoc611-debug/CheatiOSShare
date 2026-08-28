import SwiftUI
import UIKit

// MARK: - Model

private struct ManagedApp: Identifiable {
    let id: String  // bundle ID
    var name: String
    var icon: UIImage?
    var containerPath: String
}

// MARK: - Sort

private enum SortKey: Equatable { case name, size }
private enum SortDir: Equatable { case asc, desc }

// MARK: - ViewModel

private final class AppManagerModel: ObservableObject {
    @Published var apps: [ManagedApp] = []
    @Published var isLoading = true
    @Published var sizeCache: [String: Int64] = [:]

    func load() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let infoMap = installedAppInfo() as! [String: [String: Any]]
            let identifiers = MCMFilzaGatherAppIdentifiers()

            var result: [ManagedApp] = []
            var covered = Set<String>()

            for bid in identifiers {
                var errStr: NSString?
                let path = MCMFilzaDataContainerPath(bid, &errStr) ?? ""
                let info = infoMap[bid]
                let rawName = (info?["name"] as? String)?.trimmingCharacters(in: .whitespaces)
                let name = rawName?.nonEmpty ?? bid
                result.append(ManagedApp(id: bid, name: name,
                                         icon: info?["icon"] as? UIImage,
                                         containerPath: path))
                covered.insert(bid)
            }

            for (bid, info) in infoMap where !covered.contains(bid) {
                let rawName = (info["name"] as? String)?.trimmingCharacters(in: .whitespaces)
                let name = rawName?.nonEmpty ?? bid
                result.append(ManagedApp(id: bid, name: name,
                                         icon: info["icon"] as? UIImage,
                                         containerPath: ""))
            }

            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async { [weak self] in
                self?.apps = result
                self?.isLoading = false
            }
        }
    }

    func fetchSize(for app: ManagedApp) {
        guard !app.containerPath.isEmpty, sizeCache[app.id] == nil else { return }
        sizeCache[app.id] = -1
        let path = app.containerPath
        let bid = app.id
        DispatchQueue.global(qos: .background).async { [weak self] in
            var total: Int64 = 0
            if let e = FileManager.default.enumerator(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                for case let url as URL in e {
                    total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                    if total > 50 * 1_024 * 1_024 * 1_024 { break }
                }
            }
            DispatchQueue.main.async { [weak self] in self?.sizeCache[bid] = total }
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

// MARK: - AppManagerView

struct AppManagerView: View {
    @StateObject private var model = AppManagerModel()
    @State private var searchText = ""
    @State private var searchActive = false
    @State private var sortKey: SortKey = .name
    @State private var sortDir: SortDir = .asc

    private var displayed: [ManagedApp] {
        var base = model.apps
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            base = base.filter {
                $0.name.lowercased().contains(q) || $0.id.lowercased().contains(q)
            }
        }
        switch (sortKey, sortDir) {
        case (.name, .asc):  break
        case (.name, .desc): base = base.reversed()
        case (.size, .asc):
            base.sort { (model.sizeCache[$0.id] ?? 0) < (model.sizeCache[$1.id] ?? 0) }
        case (.size, .desc):
            base.sort { (model.sizeCache[$0.id] ?? 0) > (model.sizeCache[$1.id] ?? 0) }
        }
        return base
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filza-style sort bar
            sortBar

            // Search bar (appears only when 🔍 tapped)
            if searchActive {
                searchBar
            }

            Divider().background(Color.white.opacity(0.10))
            content
        }
        .background(Color(red: 0.047, green: 0.063, blue: 0.118))
        .onAppear { if model.apps.isEmpty && model.isLoading { model.load() } }
    }

    // MARK: - Sort bar (matches Filza exactly)
    // Layout: [🔍] | [^ Tên] | [◇ Kích thước] | [< ⊞]

    private var sortBar: some View {
        HStack(spacing: 0) {
            // 🔍 search toggle
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    searchActive.toggle()
                    if !searchActive { searchText = "" }
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(searchActive
                        ? AppTheme.neonPurple
                        : Color(red: 0.50, green: 0.58, blue: 0.75))
                    .frame(width: 42, height: 38)
            }

            Divider().frame(height: 20).background(Color.white.opacity(0.12))

            // Tên sort
            Button {
                if sortKey == .name {
                    sortDir = sortDir == .asc ? .desc : .asc
                } else {
                    sortKey = .name; sortDir = .asc
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: sortKey == .name
                        ? (sortDir == .asc ? "chevron.up" : "chevron.down")
                        : "diamond")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(sortKey == .name
                            ? AppTheme.neonPurple
                            : Color(red: 0.50, green: 0.60, blue: 0.78))
                    Text("Tên")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(sortKey == .name
                            ? AppTheme.neonPurple
                            : Color(red: 0.50, green: 0.60, blue: 0.78))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 38)
            }

            Divider().frame(height: 20).background(Color.white.opacity(0.12))

            // Kích thước sort
            Button {
                if sortKey == .size {
                    sortDir = sortDir == .desc ? .asc : .desc
                } else {
                    sortKey = .size; sortDir = .desc
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: sortKey == .size
                        ? (sortDir == .desc ? "chevron.down" : "chevron.up")
                        : "diamond")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(sortKey == .size
                            ? AppTheme.neonPurple
                            : Color(red: 0.50, green: 0.60, blue: 0.78))
                    Text("Kích thước")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(sortKey == .size
                            ? AppTheme.neonPurple
                            : Color(red: 0.50, green: 0.60, blue: 0.78))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 38)
            }

            Divider().frame(height: 20).background(Color.white.opacity(0.12))

            // Grid toggle (decorative — matches Filza's < ⊞)
            HStack(spacing: 4) {
                Image(systemName: "lessthan")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 0.50, green: 0.58, blue: 0.75))
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.50, green: 0.58, blue: 0.75))
            }
            .frame(width: 46, height: 38)
        }
        .background(Color(red: 0.068, green: 0.090, blue: 0.155))
    }

    // MARK: - Search bar (Filza-style, shown below sort bar)

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(red: 0.50, green: 0.60, blue: 0.78))
                .font(.system(size: 14))
            TextField("Tìm kiếm ứng dụng...", text: $searchText)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(red: 0.50, green: 0.58, blue: 0.75))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.068, green: 0.090, blue: 0.155))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.apps.isEmpty {
            Spacer()
            VStack(spacing: 14) {
                ProgressView().tint(AppTheme.neonPurple).scaleEffect(1.3)
                Text("Đang tải danh sách ứng dụng...")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
            }
            Spacer()
        } else if displayed.isEmpty {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "tray")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AppTheme.neonPurple.opacity(0.5))
                Text(searchText.isEmpty ? "Không tìm thấy ứng dụng" : "Không có kết quả")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
            }
            Spacer()
        } else {
            // App count header (like Filza top-right "N ứng dụng")
            HStack {
                Spacer()
                Text("\(displayed.count) ứng dụng")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.45, green: 0.55, blue: 0.72))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }
            .background(Color(red: 0.068, green: 0.090, blue: 0.155))

            Divider().background(Color.white.opacity(0.08))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(displayed) { app in
                        AppManagerRow(app: app, cachedSize: model.sizeCache[app.id])
                            .onAppear { model.fetchSize(for: app) }
                        Divider()
                            .background(Color.white.opacity(0.07))
                            .padding(.leading, 72)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Row (Filza-style: single name line, crosshatch placeholder)

private struct AppManagerRow: View {
    let app: ManagedApp
    let cachedSize: Int64?

    @State private var icon: UIImage?

    private var sizeLabel: String {
        guard let s = cachedSize else { return "" }
        if s < 0 { return "" }
        if s == 0 { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: s, countStyle: .file)
    }

    private var asInstalledApp: InstalledApp {
        InstalledApp(bundleID: app.id, name: app.name,
                     containerPath: app.containerPath, version: "", icon: icon ?? app.icon)
    }

    var body: some View {
        NavigationLink(destination: AppDetailView(app: asInstalledApp)) {
            HStack(spacing: 12) {
                // Icon (50pt like Filza)
                iconView
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    )

                // Name only (Filza shows 1 line, no bundle ID)
                Text(app.name)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 6)

                // Size
                Group {
                    if cachedSize == -1 {
                        ProgressView().controlSize(.mini)
                            .tint(Color(red: 0.48, green: 0.57, blue: 0.74))
                    } else if !sizeLabel.isEmpty {
                        Text(sizeLabel)
                            .font(.system(size: 14).monospacedDigit())
                            .foregroundStyle(Color(red: 0.55, green: 0.64, blue: 0.80))
                    }
                }
                .frame(minWidth: 52, alignment: .trailing)

                // ⓘ button
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(red: 0.30, green: 0.55, blue: 0.95))
                    .frame(width: 30)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.40, green: 0.48, blue: 0.65))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(Color(red: 0.047, green: 0.063, blue: 0.118))
        }
        .buttonStyle(.plain)
        .onAppear { loadIcon() }
    }

    // Filza crosshatch placeholder for system apps without icon
    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(red: 0.16, green: 0.18, blue: 0.24)
                // Crosshatch grid like Filza system app placeholder
                Canvas { ctx, size in
                    let step: CGFloat = 9
                    var path = Path()
                    var x: CGFloat = 0
                    while x <= size.width + size.height {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: x))
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: size.width, y: x - size.width + size.height))
                        x += step
                    }
                    ctx.stroke(path, with: .color(Color(red: 0.28, green: 0.32, blue: 0.42)),
                               lineWidth: 0.7)
                }
            }
        }
    }

    private func loadIcon() {
        guard icon == nil else { return }
        if let cached = app.icon { icon = cached; return }
        let bid = app.id
        DispatchQueue.global(qos: .utility).async {
            let img = iconForBundleID(bid)
            DispatchQueue.main.async { icon = img }
        }
    }
}
