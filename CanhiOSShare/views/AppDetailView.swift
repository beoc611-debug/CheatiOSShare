import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Folder picker (chọn thư mục lưu TRƯỚC khi xuất)

private struct DocumentFolderPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentFolderPicker
        init(_ p: DocumentFolderPicker) { parent = p }
        func documentPicker(_ c: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}

// MARK: - AppDetailView

struct AppDetailView: View {
    let app: InstalledApp
    @Environment(\.appLanguage) private var language
    @State private var bundlePath: String?
    @State private var isLoadingBundle = true
    @State private var isExportingZip = false
    @State private var isExportingIPA = false
    @State private var toast: ToastMessage?
    @State private var showZipPicker = false
    @State private var showIPAPicker = false
    @State private var exportProgress: Double = 0
    @State private var isShowingProgress = false
    @State private var progressTitle = ""

    var body: some View {
        List {
            headerSection
            quickActionsSection
            fileManagementSection
            infoSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(app.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .task { await loadBundlePath() }
        .sheet(isPresented: $showZipPicker) {
            DocumentFolderPicker { folderURL in
                showZipPicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    doZipExport(to: folderURL)
                }
            }
        }
        .sheet(isPresented: $showIPAPicker) {
            DocumentFolderPicker { folderURL in
                showIPAPicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard let bp = bundlePath else { return }
                    doIPAExport(bundlePath: bp, to: folderURL)
                }
            }
        }
        .overlay {
            if isShowingProgress { progressOverlay }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 14) {
                BrowserAppIcon(app: app, size: 60)
                VStack(alignment: .leading, spacing: 5) {
                    Text(app.displayName)
                        .font(.headline)
                    Text(app.bundleID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var quickActionsSection: some View {
        Section {
            Button { openApp() } label: {
                Label(language.text("appdetail.open"), systemImage: "play.fill")
            }
        } header: {
            Text(language.text("appdetail.quick"))
        }
    }

    private var fileManagementSection: some View {
        Section {
            // Browse App Bundle
            if isLoadingBundle {
                HStack {
                    Label(language.text("appdetail.browse_bundle"), systemImage: "shippingbox")
                        .foregroundStyle(.secondary)
                    Spacer()
                    ProgressView().controlSize(.small)
                }
            } else if let bp = bundlePath {
                NavigationLink {
                    FileBrowserView(
                        containerPath: bp,
                        title: (bp as NSString).lastPathComponent,
                        bundleID: app.bundleID
                    )
                } label: {
                    Label(language.text("appdetail.browse_bundle"), systemImage: "shippingbox")
                }
            } else {
                Label(language.text("appdetail.browse_bundle"), systemImage: "shippingbox")
                    .foregroundStyle(.secondary)
            }

            // Export Data ZIP
            if isExportingZip {
                HStack {
                    Label("Đang xuất \(Int(exportProgress * 100))%", systemImage: "archivebox")
                        .foregroundStyle(AppTheme.neonPurple)
                    Spacer()
                    ProgressView(value: exportProgress)
                        .frame(width: 64)
                        .tint(AppTheme.neonPurple)
                        .animation(.linear(duration: 0.15), value: exportProgress)
                }
            } else {
                Button { showZipPicker = true } label: {
                    Label(language.text("appdetail.export_zip"), systemImage: "archivebox")
                }
                .disabled(app.containerPath.isEmpty || isExportingIPA)
            }

            // Export IPA
            if isExportingIPA {
                HStack {
                    let label = exportProgress > 0
                        ? "Đang xuất \(Int(exportProgress * 100))%"
                        : "Đang sao chép..."
                    Label(label, systemImage: "doc.zipper")
                        .foregroundStyle(AppTheme.neonPurple)
                    Spacer()
                    if exportProgress > 0 {
                        ProgressView(value: exportProgress)
                            .frame(width: 64)
                            .tint(AppTheme.neonPurple)
                            .animation(.linear(duration: 0.15), value: exportProgress)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
            } else {
                Button { showIPAPicker = true } label: {
                    Label(language.text("appdetail.export_ipa"), systemImage: "doc.zipper")
                }
                .disabled(bundlePath == nil || isLoadingBundle || isExportingZip)
            }

        } header: {
            Text(language.text("appdetail.files"))
        }
    }

    private var infoSection: some View {
        Section {
            if !app.version.isEmpty {
                LabeledRow(language.text("appdetail.version"), value: app.version)
            }
            LabeledRow("Bundle ID") {
                Text(app.bundleID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
            if !app.containerPath.isEmpty {
                LabeledRow("Container") {
                    Text(app.containerPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        } header: {
            Text(language.text("appdetail.info"))
        }
    }

    // MARK: - Progress overlay

    private var progressOverlay: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: max(0.03, exportProgress))
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.neonCyan, AppTheme.neonPurple],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.15), value: exportProgress)
                    Text("\(Int(exportProgress * 100))%")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(width: 90, height: 90)

                Text(progressTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.068, green: 0.098, blue: 0.180))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.neonPurple.opacity(0.25), radius: 30)
            )
            .padding(.horizontal, 60)
        }
    }

    // MARK: - Actions

    private func loadBundlePath() async {
        isLoadingBundle = true
        let bid = app.bundleID
        bundlePath = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: ContainerStore.bundlePathForBundleID(bid))
            }
        }
        isLoadingBundle = false
    }

    private func openApp() {
        guard let clazz = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let ws = clazz.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue() as? NSObject else {
            toast = ToastMessage(text: language.text("appdetail.open_fail"))
            return
        }
        ws.perform(Selector(("openApplicationWithBundleID:")), with: app.bundleID)
    }

    // MARK: - ZIP export

    private func doZipExport(to folderURL: URL) {
        guard !app.containerPath.isEmpty else { return }
        isExportingZip = true
        exportProgress = 0
        isShowingProgress = true
        progressTitle = "Đang nén DATA..."

        let containerURL = URL(fileURLWithPath: app.containerPath)
        let appName = app.displayName.isEmpty ? app.bundleID : app.displayName
        let destURL = folderURL.appendingPathComponent("\(appName)-data.zip")

        DispatchQueue.global(qos: .userInitiated).async {
            // Count files first for accurate progress
            var total = 0
            if let e = FileManager.default.enumerator(at: containerURL, includingPropertiesForKeys: nil) {
                while e.nextObject() != nil { total += 1 }
            }
            let totalFiles = max(1, total)
            var done = 0

            let didAccess = folderURL.startAccessingSecurityScopedResource()
            let fm = FileManager.default
            try? fm.removeItem(at: destURL)

            do {
                _ = try ZIPArchiveWriter.write(
                    items: [containerURL],
                    to: destURL,
                    fileWritten: {
                        done += 1
                        let p = min(0.97, Double(done) / Double(totalFiles))
                        DispatchQueue.main.async { exportProgress = p }
                    }
                )
                if didAccess { folderURL.stopAccessingSecurityScopedResource() }
                DispatchQueue.main.async {
                    progressTitle = "Hoàn thành!"
                    withAnimation(.easeOut(duration: 0.25)) { exportProgress = 1.0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        isExportingZip = false
                        isShowingProgress = false
                        exportProgress = 0
                        toast = ToastMessage(text: "✓ Đã lưu vào Tệp thành công!")
                    }
                }
            } catch {
                if didAccess { folderURL.stopAccessingSecurityScopedResource() }
                DispatchQueue.main.async {
                    isExportingZip = false
                    isShowingProgress = false
                    exportProgress = 0
                    toast = ToastMessage(text: "Lỗi: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - IPA export

    private func doIPAExport(bundlePath: String, to folderURL: URL) {
        isExportingIPA = true
        exportProgress = 0
        isShowingProgress = true
        progressTitle = "Đang sao chép bundle..."

        let appName = app.displayName.isEmpty ? app.bundleID : app.displayName
        let destURL = folderURL.appendingPathComponent("\(appName).ipa")
        let bundleURL = URL(fileURLWithPath: bundlePath)

        DispatchQueue.global(qos: .userInitiated).async {
            // Count bundle files for ZIP progress phase
            var total = 0
            if let e = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: nil) {
                while e.nextObject() != nil { total += 1 }
            }
            let totalFiles = max(1, total)
            var done = 0

            let didAccess = folderURL.startAccessingSecurityScopedResource()
            let fm = FileManager.default
            try? fm.removeItem(at: destURL)

            do {
                try ContainerStore.exportIPABundle(
                    at: bundlePath,
                    to: destURL,
                    onCopied: {
                        DispatchQueue.main.async { progressTitle = "Đang nén IPA..." }
                    },
                    fileWritten: {
                        done += 1
                        let p = min(0.97, Double(done) / Double(totalFiles))
                        DispatchQueue.main.async { exportProgress = p }
                    }
                )
                if didAccess { folderURL.stopAccessingSecurityScopedResource() }
                DispatchQueue.main.async {
                    progressTitle = "Hoàn thành!"
                    withAnimation(.easeOut(duration: 0.25)) { exportProgress = 1.0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        isExportingIPA = false
                        isShowingProgress = false
                        exportProgress = 0
                        toast = ToastMessage(text: "✓ Đã lưu IPA vào Tệp thành công!")
                    }
                }
            } catch {
                if didAccess { folderURL.stopAccessingSecurityScopedResource() }
                DispatchQueue.main.async {
                    isExportingIPA = false
                    isShowingProgress = false
                    exportProgress = 0
                    toast = ToastMessage(text: "Lỗi: \(error.localizedDescription)")
                }
            }
        }
    }

    private func shareFile(_ url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        var presenter = root
        while let p = presenter.presentedViewController { presenter = p }
        presenter.present(av, animated: true)
    }
}
