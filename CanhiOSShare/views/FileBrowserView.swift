import SwiftUI

struct FileBrowserView: View {
    let path: String
    @State private var entries: [FileEntry] = []
    @State private var isLoading = true
    @State private var selectedFile: FileEntry?
    @State private var textContent: String?
    @State private var showText = false
    @State private var errorMessage: String?
    @State private var searchQuery = ""

    var body: some View {
        ZStack {
            TechBackground()
            content
        }
        .searchable(text: $searchQuery, prompt: "Tìm file…")
        .onAppear { loadEntries() }
        .sheet(isPresented: $showText) {
            TextPreviewSheet(name: selectedFile?.name ?? "", text: textContent ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .tint(AppTheme.accent)
        } else if let error = errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.red)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else if filteredEntries.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Trống")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        } else {
            List(filteredEntries) { entry in
                row(for: entry)
                    .listRowBackground(AppTheme.card)
                    .listRowSeparatorTint(AppTheme.cardStroke)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func row(for entry: FileEntry) -> some View {
        if entry.isDirectory || entry.isSymlink {
            NavigationLink {
                FileBrowserView(path: entry.path)
                    .navigationTitle(entry.name)
            } label: {
                fileRow(entry: entry)
            }
        } else {
            Button { openFile(entry) } label: {
                fileRow(entry: entry)
            }
            .buttonStyle(.plain)
        }
    }

    private func fileRow(entry: FileEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor(for: entry))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(entry.sizeText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if entry.isSymlink {
                Text("link")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.purple.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var filteredEntries: [FileEntry] {
        if searchQuery.isEmpty { return entries }
        return entries.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    private func iconColor(for entry: FileEntry) -> Color {
        if entry.isSymlink { return AppTheme.purple }
        if entry.isDirectory { return AppTheme.accent }
        let ext = (entry.name as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "heic": return Color(red: 0.4, green: 0.7, blue: 1.0)
        case "mp4", "mov": return Color(red: 0.9, green: 0.3, blue: 0.6)
        case "mp3", "aac", "m4a": return AppTheme.green
        case "zip", "ipa": return Color(red: 1.0, green: 0.6, blue: 0.1)
        case "plist", "db", "sqlite": return Color(red: 0.9, green: 0.7, blue: 0.2)
        default: return AppTheme.textSecondary
        }
    }

    private func loadEntries() {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let result = ContainerStore.listFiles(at: path)
            await MainActor.run {
                entries = result
                if result.isEmpty && !FileManager.default.fileExists(atPath: path) {
                    errorMessage = "Không thể truy cập đường dẫn này."
                }
                isLoading = false
            }
        }
    }

    private func openFile(_ entry: FileEntry) {
        let textExts = ["txt", "log", "plist", "json", "xml", "html", "js", "css", "swift", "py", "sh", "conf", "ini", "md"]
        let ext = (entry.name as NSString).pathExtension.lowercased()
        guard textExts.contains(ext) || entry.size < 500_000 else { return }
        Task.detached(priority: .userInitiated) {
            let text = ContainerStore.readTextFile(at: entry.path)
            await MainActor.run {
                selectedFile = entry
                textContent = text
                showText = true
            }
        }
    }
}

struct TextPreviewSheet: View {
    let name: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    Text(text)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
