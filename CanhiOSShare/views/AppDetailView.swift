import SwiftUI
import UIKit

struct AppDetailView: View {
    let app: InstalledApp
    @Environment(\.appLanguage) private var language
    @State private var bundlePath: String?
    @State private var isLoadingBundle = true
    @State private var isExportingZip = false
    @State private var isExportingIPA = false
    @State private var toast: ToastMessage?

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
            // Data Container
            if !app.containerPath.isEmpty {
                NavigationLink {
                    FileBrowserView(
                        containerPath: app.containerPath,
                        title: app.displayName,
                        bundleID: app.bundleID
                    )
                } label: {
                    Label(language.text("appdetail.browse_data"), systemImage: "externaldrive")
                }
            }

            // App Bundle
            if isLoadingBundle {
                HStack {
                    Label(language.text("appdetail.browse_bundle"), systemImage: "shippingbox")
                        .foregroundStyle(.secondary)
                    Spacer()
                    ProgressView().controlSize(.small)
                }
            } else if let bundlePath {
                NavigationLink {
                    FileBrowserView(
                        containerPath: bundlePath,
                        title: (bundlePath as NSString).lastPathComponent,
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
            Button { exportZip() } label: {
                if isExportingZip {
                    HStack {
                        Label(language.text("appdetail.exporting"), systemImage: "archivebox")
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                } else {
                    Label(language.text("appdetail.export_zip"), systemImage: "archivebox")
                }
            }
            .disabled(app.containerPath.isEmpty || isExportingZip)

            // Export IPA
            Button { exportIPA() } label: {
                if isExportingIPA {
                    HStack {
                        Label(language.text("appdetail.exporting"), systemImage: "doc.zipper")
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                } else {
                    Label(language.text("appdetail.export_ipa"), systemImage: "doc.zipper")
                }
            }
            .disabled(bundlePath == nil || isLoadingBundle || isExportingIPA)

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
        guard let clazz = NSClassFromString("LSApplicationWorkspace"),
              let ws = clazz.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue() else {
            toast = ToastMessage(text: language.text("appdetail.open_fail"))
            return
        }
        if ws.perform(Selector(("openApplicationWithBundleID:")), with: app.bundleID) == nil {
            toast = ToastMessage(text: language.text("appdetail.open_fail"))
        }
    }

    private func exportZip() {
        guard !app.containerPath.isEmpty, !isExportingZip else { return }
        isExportingZip = true
        let containerURL = URL(fileURLWithPath: app.containerPath)
        let name = "\(app.displayName.isEmpty ? app.bundleID : app.displayName)-data.zip"
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try ZIPArchiveWriter.write(items: [containerURL], to: dest)
                DispatchQueue.main.async {
                    isExportingZip = false
                    shareFile(dest)
                }
            } catch {
                DispatchQueue.main.async {
                    isExportingZip = false
                    toast = ToastMessage(text: "Lỗi: \(error.localizedDescription)")
                }
            }
        }
    }

    private func exportIPA() {
        guard let bundlePath, !isExportingIPA else { return }
        isExportingIPA = true
        let appName = app.displayName.isEmpty ? app.bundleID : app.displayName
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(appName).ipa")
        let payloadURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Payload-\(UUID().uuidString)")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fm = FileManager.default
                try? fm.removeItem(at: dest)
                try? fm.removeItem(at: payloadURL)
                try fm.createDirectory(at: payloadURL, withIntermediateDirectories: true)
                let bundleName = (bundlePath as NSString).lastPathComponent
                try fm.copyItem(
                    at: URL(fileURLWithPath: bundlePath),
                    to: payloadURL.appendingPathComponent(bundleName)
                )
                _ = try ZIPArchiveWriter.write(items: [payloadURL], to: dest)
                try? fm.removeItem(at: payloadURL)
                DispatchQueue.main.async {
                    isExportingIPA = false
                    shareFile(dest)
                }
            } catch {
                try? FileManager.default.removeItem(at: payloadURL)
                DispatchQueue.main.async {
                    isExportingIPA = false
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
