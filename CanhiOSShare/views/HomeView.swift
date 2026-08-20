import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                TechBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        LicenseStatusBar()
                            .padding(.top, 8)

                        deviceCard
                        entryGrid
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Cảnh iOS Share")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(AppTheme.techGlow)
                    }
                }
            })
            .hideToolbarBackground()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var deviceCard: some View {
        TechCard {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "iphone")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppInfo.hardwareDisplayName)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("iOS \(UIDevice.current.systemVersion)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.green)
                            .frame(width: 7, height: 7)
                        Text("Đã kết nối • Sandbox mở")
                            .font(.caption)
                            .foregroundStyle(AppTheme.green)
                    }
                }
                Spacer()
            }
        }
    }

    private var entryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vị trí")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(LocationEntry.all) { entry in
                    NavigationLink {
                        destination(for: entry)
                    } label: {
                        EntryCard(entry: entry)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for entry: LocationEntry) -> some View {
        if entry.path == "__applist__" {
            AppListView()
        } else {
            FileBrowserView(path: appState.virtualRoot.isEmpty ? entry.path : resolvedVirtualPath(entry))
                .navigationTitle(entry.title)
        }
    }

    private func resolvedVirtualPath(_ entry: LocationEntry) -> String {
        let root = appState.virtualRoot
        switch entry.path {
        case "/private/var/mobile/Containers/Data/Application":
            return (root as NSString).appendingPathComponent("[MHA-C2] App Data")
        case "/private/var/mobile/Containers/Shared/AppGroup":
            return (root as NSString).appendingPathComponent("[MHA-C7] App Groups")
        case "/private/var/mobile/Containers/Data/System":
            return (root as NSString).appendingPathComponent("[MHA-C12] System Data")
        case "/private/var/mobile":
            return (root as NSString).appendingPathComponent("14 Mobile Home - Best Effort")
        case "/private/var/mobile/Library/SpringBoard":
            return (root as NSString).appendingPathComponent("[MHA-C2] Wallpaper Lab")
        default:
            return entry.path
        }
    }
}
