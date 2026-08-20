import SwiftUI

struct AppListView: View {
    @StateObject private var service = InstalledAppService()
    @State private var searchQuery = ""

    var body: some View {
        ZStack {
            TechBackground()
            content
        }
        .navigationTitle("Ứng dụng")
        .searchable(text: $searchQuery, prompt: "Tìm theo tên hoặc bundle ID…")
        .task { await service.load() }
    }

    @ViewBuilder
    private var content: some View {
        if service.isLoading {
            VStack(spacing: 14) {
                ProgressView()
                    .tint(AppTheme.accent)
                Text("Đang tải danh sách app…")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        } else if filteredApps.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "apps.iphone")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Không tìm thấy")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        } else {
            List(filteredApps) { app in
                NavigationLink {
                    FileBrowserView(path: app.containerPath)
                        .navigationTitle(app.displayName)
                } label: {
                    appRow(app)
                }
                .listRowBackground(AppTheme.card)
                .listRowSeparatorTint(AppTheme.cardStroke)
            }
            .listStyle(.plain)
            .hideScrollBackground()
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Text(String(app.displayName.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.accent)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if !app.version.isEmpty {
                Text(app.version)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var filteredApps: [InstalledApp] {
        if searchQuery.isEmpty { return service.apps }
        return service.apps.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            $0.bundleID.localizedCaseInsensitiveContains(searchQuery)
        }
    }
}
