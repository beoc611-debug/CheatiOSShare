import SwiftUI
import WebKit

// MARK: - Main SwiftUI View

struct MakeFileView: View {
    @State private var showShare = false
    @State private var shareURL: URL?

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.027, green: 0.043, blue: 0.082).ignoresSafeArea()
            VStack(spacing: 0) {
                makeFileHeader
                MakeFileWebView { filename, data in
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(filename)
                    try? data.write(to: tmp)
                    shareURL = tmp
                    showShare = true
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL {
                MakeFileShareSheet(url: url)
            }
        }
    }

    private var makeFileHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(
                        colors: [AppTheme.neonPurple.opacity(0.28), AppTheme.techGlow.opacity(0.14)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(AppTheme.neonPurple.opacity(0.42), lineWidth: 1)
                    )
                Image(systemName: "doc.badge.gearshape.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [AppTheme.techGlow, AppTheme.neonPurple],
                        startPoint: .top, endPoint: .bottom))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Make File")
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 0.26, green: 0.55, blue: 1.00),
                                 Color(red: 0.48, green: 0.37, blue: 1.00)],
                        startPoint: .leading, endPoint: .trailing))
                Text("Sửa UnityFS bundle · Free Fire mod")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(red: 0.04, green: 0.05, blue: 0.13))
    }
}

// MARK: - WKWebView wrapper

struct MakeFileWebView: UIViewRepresentable {
    let onSaveFile: (String, Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSaveFile: onSaveFile)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "saveFile")
        // Allow file access for <input type="file"> from document picker
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.backgroundColor = UIColor(red: 0.027, green: 0.043, blue: 0.082, alpha: 1)
        webView.isOpaque = false
        webView.scrollView.backgroundColor = UIColor(red: 0.027, green: 0.043, blue: 0.082, alpha: 1)

        if let url = Bundle.main.url(forResource: "make-file", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator / message handler

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let onSaveFile: (String, Data) -> Void

        init(onSaveFile: @escaping (String, Data) -> Void) {
            self.onSaveFile = onSaveFile
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "saveFile",
                  let body = message.body as? [String: Any],
                  let filename = body["name"] as? String,
                  let b64 = body["b64"] as? String,
                  let data = Data(base64Encoded: b64)
            else { return }
            DispatchQueue.main.async { self.onSaveFile(filename, data) }
        }
    }
}

// MARK: - Share sheet

private struct MakeFileShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
