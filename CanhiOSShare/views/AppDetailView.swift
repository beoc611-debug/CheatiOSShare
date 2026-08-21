import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - AppDetailView

struct AppDetailView: View {
    let app: InstalledApp
    @Environment(\.appLanguage) private var language
    @State private var bundlePath: String?
    @State private var isLoadingBundle = true
    @State private var isExportingZip = false
    @State private var isExportingIPA = false
    @State private var toast: ToastMessage?
    @State private var exportProgress: Double = 0
    @State private var isShowingProgress = false
    @State private var progressTitle = ""

    var body: some View {
        ZStack {
            Color(red: 0.047, green: 0.063, blue: 0.118).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    quickActionsCard
                    fileManagementCard
                    infoCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(app.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.047, green: 0.063, blue: 0.118), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(AppTheme.neonPurple)
        .preferredColorScheme(.dark)
        .toast($toast)
        .task { await loadBundlePath() }
        .overlay {
            if isShowingProgress { progressOverlay }
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        HStack(spacing: 14) {
            BrowserAppIcon(app: app, size: 64)
            VStack(alignment: .leading, spacing: 5) {
                Text(app.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(app.bundleID)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                    .lineLimit(2)
                    .textSelection(.enabled)
                if !app.version.isEmpty {
                    Text("v\(app.version)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.neonCyan.opacity(0.8))
                }
            }
            Spacer()
        }
        .padding(16)
        .techCard()
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: language.text("appdetail.quick"), icon: "bolt.fill", color: AppTheme.neonCyan)

            Button {
                openApp()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.neonCyan.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.neonCyan)
                    }
                    Text(language.text("appdetail.open"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.40, green: 0.50, blue: 0.70))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
        }
        .techCard()
    }

    private var fileManagementCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: language.text("appdetail.files"), icon: "folder.fill", color: AppTheme.neonPurple)

            // Browse App Bundle
            Group {
                if isLoadingBundle {
                    HStack(spacing: 12) {
                        iconCircle("shippingbox", color: Color(red: 0.52, green: 0.63, blue: 0.82))
                        Text(language.text("appdetail.browse_bundle"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                        Spacer()
                        ProgressView().controlSize(.small).tint(AppTheme.neonPurple)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                } else if let bp = bundlePath {
                    NavigationLink {
                        FileBrowserView(
                            containerPath: bp,
                            title: (bp as NSString).lastPathComponent,
                            bundleID: app.bundleID
                        )
                    } label: {
                        HStack(spacing: 12) {
                            iconCircle("shippingbox", color: AppTheme.neonPurple)
                            Text(language.text("appdetail.browse_bundle"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(red: 0.40, green: 0.50, blue: 0.70))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                    }
                } else {
                    HStack(spacing: 12) {
                        iconCircle("shippingbox", color: Color(red: 0.35, green: 0.40, blue: 0.55))
                        Text(language.text("appdetail.browse_bundle"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(red: 0.35, green: 0.40, blue: 0.55))
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                }
            }

            divider

            // Export Data ZIP
            if isExportingZip {
                exportingRow(icon: "archivebox.fill", color: AppTheme.techGlow)
            } else {
                Button {
                    startZipExport()
                } label: {
                    HStack(spacing: 12) {
                        iconCircle("archivebox.fill", color: AppTheme.techGlow)
                        Text(language.text("appdetail.export_zip"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 0.40, green: 0.50, blue: 0.70))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                }
                .disabled(app.containerPath.isEmpty || isExportingIPA)
                .opacity(app.containerPath.isEmpty || isExportingIPA ? 0.45 : 1)
            }

            divider

            // Export IPA
            if isExportingIPA {
                exportingRow(icon: "doc.zipper", color: AppTheme.neonPurple)
            } else {
                Button {
                    startIPAExport()
                } label: {
                    HStack(spacing: 12) {
                        iconCircle("doc.zipper", color: AppTheme.neonPurple)
                        Text(language.text("appdetail.export_ipa"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 0.40, green: 0.50, blue: 0.70))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                }
                .disabled(bundlePath == nil || isLoadingBundle || isExportingZip)
                .opacity(bundlePath == nil || isLoadingBundle || isExportingZip ? 0.45 : 1)
            }
        }
        .techCard()
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: language.text("appdetail.info"), icon: "info.circle.fill", color: AppTheme.techGlow)

            if !app.version.isEmpty {
                infoRow(label: language.text("appdetail.version"), value: app.version)
                divider
            }
            infoRowMultiline(label: "Bundle ID", value: app.bundleID)
            if !app.containerPath.isEmpty {
                divider
                infoRowMultiline(label: "Container", value: app.containerPath)
            }
        }
        .techCard()
    }

    // MARK: - Reusable sub-views

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                .tracking15(1.2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func iconCircle(_ systemImage: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 36, height: 36)
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private func exportingRow(icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            iconCircle(icon, color: color)
            VStack(alignment: .leading, spacing: 4) {
                Text(progressTitle.isEmpty ? "Đang xuất..." : progressTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(color)
                ProgressView(value: max(0.02, exportProgress))
                    .tint(color)
                    .animation(.linear(duration: 0.15), value: exportProgress)
            }
            Spacer()
            Text("\(Int(exportProgress * 100))%")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func infoRowMultiline(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .frame(maxWidth: 220, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [Color.clear, AppTheme.techGlow.opacity(0.15), Color.clear],
                startPoint: .leading, endPoint: .trailing
            ))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    // MARK: - Progress overlay

    private var progressOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
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
                    .shadow(color: AppTheme.neonPurple.opacity(0.3), radius: 30)
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

    // MARK: - ZIP export (export to temp first, then forExporting: picker)

    private func startZipExport() {
        guard !app.containerPath.isEmpty else { return }
        isExportingZip = true
        exportProgress = 0
        isShowingProgress = true
        progressTitle = "Đang nén DATA..."

        let containerURL = URL(fileURLWithPath: app.containerPath)
        let appName = app.displayName.isEmpty ? app.bundleID : app.displayName
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(appName)-data-\(Int(Date().timeIntervalSince1970)).zip")

        DispatchQueue.global(qos: .userInitiated).async {
            var total = 0
            if let e = FileManager.default.enumerator(at: containerURL, includingPropertiesForKeys: nil) {
                while e.nextObject() != nil { total += 1 }
            }
            let totalFiles = max(1, total)
            var done = 0
            try? FileManager.default.removeItem(at: dest)

            do {
                _ = try ZIPArchiveWriter.write(
                    items: [containerURL],
                    to: dest,
                    fileWritten: {
                        done += 1
                        let p = min(0.97, Double(done) / Double(totalFiles))
                        DispatchQueue.main.async { exportProgress = p }
                    }
                )
                DispatchQueue.main.async {
                    progressTitle = "Hoàn thành!"
                    withAnimation { exportProgress = 1.0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isShowingProgress = false
                        isExportingZip = false
                        exportProgress = 0
                        presentExportPicker(url: dest)
                    }
                }
            } catch {
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

    private func startIPAExport() {
        guard let bp = bundlePath else { return }
        isExportingIPA = true
        exportProgress = 0
        isShowingProgress = true
        progressTitle = "Đang sao chép bundle..."

        let appName = app.displayName.isEmpty ? app.bundleID : app.displayName
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(appName)-\(Int(Date().timeIntervalSince1970)).ipa")
        let bundleURL = URL(fileURLWithPath: bp)

        DispatchQueue.global(qos: .userInitiated).async {
            var total = 0
            if let e = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: nil) {
                while e.nextObject() != nil { total += 1 }
            }
            let totalFiles = max(1, total)
            var done = 0
            try? FileManager.default.removeItem(at: dest)

            do {
                try ContainerStore.exportIPABundle(
                    at: bp,
                    to: dest,
                    onCopied: {
                        DispatchQueue.main.async { progressTitle = "Đang nén IPA..." }
                    },
                    fileWritten: {
                        done += 1
                        let p = min(0.97, Double(done) / Double(totalFiles))
                        DispatchQueue.main.async { exportProgress = p }
                    }
                )
                DispatchQueue.main.async {
                    progressTitle = "Hoàn thành!"
                    withAnimation { exportProgress = 1.0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isShowingProgress = false
                        isExportingIPA = false
                        exportProgress = 0
                        presentExportPicker(url: dest)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isExportingIPA = false
                    isShowingProgress = false
                    exportProgress = 0
                    toast = ToastMessage(text: "Lỗi: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - UIDocumentPickerViewController forExporting (nút "Xuất" thay vì "Mở")

    private func presentExportPicker(url: URL) {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.shouldShowFileExtensions = true
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            toast = ToastMessage(text: "✓ File đã tạo, chia sẻ thủ công từ Tệp")
            return
        }
        var presenter = root
        while let p = presenter.presentedViewController { presenter = p }
        presenter.present(picker, animated: true)
    }
}
