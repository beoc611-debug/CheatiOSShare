import SwiftUI

// MARK: - Hex color helper

private extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}

// MARK: - SSL bypass for tool API servers

private class TrustAllDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

private let trustAllSession: URLSession = {
    URLSession(configuration: .default, delegate: TrustAllDelegate(), delegateQueue: nil)
}()

// MARK: - ViewModel

@MainActor
final class VipToolsViewModel: ObservableObject {
    @Published var tools: [RemoteTool] = []
    @Published var isLoading = false
    @Published var loadError: String? = nil

    func load() async {
        isLoading = true
        loadError = nil
        do {
            tools = try await PatchHubService.fetchTools()
        } catch {
            loadError = "Không tải được danh sách công cụ"
        }
        isLoading = false
    }
}

// MARK: - Main View

struct VipToolsView: View {
    @StateObject private var vm = VipToolsViewModel()
    @State private var activeTool: RemoteTool? = nil

    var body: some View {
        ZStack {
            Color.clear
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                    toolsList
                        .padding(.horizontal, 14)
                    Spacer(minLength: 40)
                }
            }
            .refreshable { await vm.load() }
        }
        .sheet(item: $activeTool) { tool in
            DynamicToolSheet(tool: tool)
        }
        .task { await vm.load() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: [AppTheme.neonPurple.opacity(0.28), AppTheme.techGlow.opacity(0.14)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.neonPurple.opacity(0.40), lineWidth: 1))
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [AppTheme.techGlow, AppTheme.neonPurple],
                        startPoint: .top, endPoint: .bottom))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Vip Tools")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 0.26, green: 0.55, blue: 1.00),
                                 Color(red: 0.48, green: 0.37, blue: 1.00)],
                        startPoint: .leading, endPoint: .trailing))
                Text("Công cụ cao cấp · Độc quyền VIP")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
            }
            Spacer()
        }
    }

    // MARK: Tools list

    @ViewBuilder
    private var toolsList: some View {
        if vm.isLoading && vm.tools.isEmpty {
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.08, green: 0.12, blue: 0.20).opacity(0.60))
                        .frame(height: 70)
                        .redacted(reason: .placeholder)
                        .shimmering()
                }
            }
        } else if let err = vm.loadError, vm.tools.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(red: 0.60, green: 0.40, blue: 0.90))
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                    .multilineTextAlignment(.center)
                Button {
                    Task { await vm.load() }
                } label: {
                    Text("Thử lại")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.26, green: 0.55, blue: 1.00))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.10, green: 0.18, blue: 0.34), in: Capsule())
                }
            }
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 10) {
                ForEach(vm.tools) { tool in
                    ToolRowCard(tool: tool) { activeTool = tool }
                }
            }
        }
    }
}

// MARK: - Shimmer modifier (simple)

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: phase - 0.3),
                        .init(color: .white.opacity(0.06), location: phase),
                        .init(color: .clear, location: phase + 0.3)
                    ],
                    startPoint: .leading, endPoint: .trailing)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

private extension View {
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Row Card

struct ToolRowCard: View {
    let tool: RemoteTool
    let action: () -> Void

    private var colors: [Color] {
        [Color(hex: tool.color1) ?? .orange, Color(hex: tool.color2) ?? .red]
    }

    var body: some View {
        Button { action() } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(
                            colors: colors.map { $0.opacity(0.22) },
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                    Image(systemName: tool.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(LinearGradient(
                            colors: colors, startPoint: .top, endPoint: .bottom))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(tool.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(tool.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(red: 0.50, green: 0.58, blue: 0.75))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("LIVE")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundStyle(colors[0])
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(colors[0].opacity(0.14), in: Capsule())
                    .overlay(Capsule().strokeBorder(colors[0].opacity(0.30), lineWidth: 1))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.52, blue: 0.70))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.90))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [colors[0].opacity(0.45), colors[1].opacity(0.18)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dynamic Tool Sheet

struct DynamicToolSheet: View {
    let tool: RemoteTool

    @State private var input1 = ""
    @State private var input2 = ""
    @State private var isRunning = false
    @State private var responseText: String? = nil
    @State private var isError = false

    private var colors: [Color] {
        [Color(hex: tool.color1) ?? .orange, Color(hex: tool.color2) ?? .red]
    }

    private var isDual: Bool { tool.inputType == "dual" }
    private var canRun: Bool {
        let v1 = input1.trimmingCharacters(in: .whitespaces)
        let v2 = input2.trimmingCharacters(in: .whitespaces)
        return !v1.isEmpty && (!isDual || !v2.isEmpty)
    }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.12).ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 18)

                ScrollView {
                    VStack(spacing: 18) {
                        // Title row
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: colors.map { $0.opacity(0.20) },
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 48, height: 48)
                                Image(systemName: tool.icon)
                                    .font(.system(size: 21, weight: .bold))
                                    .foregroundStyle(LinearGradient(
                                        colors: colors, startPoint: .top, endPoint: .bottom))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tool.title)
                                    .font(.system(size: 19, weight: .black))
                                    .foregroundStyle(.white)
                                Text(tool.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // Input 1
                        inputField(
                            label: tool.input1Label,
                            placeholder: tool.input1Placeholder,
                            icon: isDual ? "person.3.fill" : "person.fill",
                            text: $input1,
                            numberPad: !isDual
                        )

                        // Input 2 (dual only)
                        if isDual {
                            inputField(
                                label: tool.input2Label ?? "ID Game",
                                placeholder: tool.input2Placeholder ?? "Nhập ID...",
                                icon: "person.fill",
                                text: $input2,
                                numberPad: false
                            )
                        }

                        // Run button
                        Button {
                            Task { await run() }
                        } label: {
                            HStack(spacing: 8) {
                                if isRunning {
                                    ProgressView().tint(.white).scaleEffect(0.82)
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                Text(isRunning ? "Đang chạy..." : tool.runLabel)
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Group {
                                    if !canRun || isRunning {
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .fill(Color(red: 0.14, green: 0.16, blue: 0.24))
                                    } else {
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .fill(LinearGradient(
                                                colors: colors,
                                                startPoint: .leading, endPoint: .trailing))
                                    }
                                }
                            )
                        }
                        .disabled(!canRun || isRunning)
                        .padding(.horizontal, 20)

                        // Response
                        if let text = responseText {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(isError
                                            ? Color(red: 1.00, green: 0.28, blue: 0.22)
                                            : Color(red: 0.18, green: 0.84, blue: 0.44))
                                    Text(isError ? "Lỗi" : "Phản hồi")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isError
                                            ? Color(red: 1.00, green: 0.28, blue: 0.22)
                                            : Color(red: 0.18, green: 0.84, blue: 0.44))
                                }
                                Text(text)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(red: 0.05, green: 0.07, blue: 0.14))
                                    )
                            }
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: responseText)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private func inputField(
        label: String,
        placeholder: String,
        icon: String,
        text: Binding<String>,
        numberPad: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                .padding(.horizontal, 20)
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.42, green: 0.50, blue: 0.70))
                TextField("", text: text, prompt:
                    Text(placeholder).foregroundColor(Color(red: 0.32, green: 0.40, blue: 0.60)))
                    .keyboardType(numberPad ? .numberPad : .default)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .tint(colors[0])
                if !text.wrappedValue.isEmpty {
                    Button { text.wrappedValue = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(red: 0.38, green: 0.46, blue: 0.62))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.10, blue: 0.18))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color(red: 0.18, green: 0.26, blue: 0.42), lineWidth: 1))
            )
            .padding(.horizontal, 20)
        }
    }

    private func run() async {
        let v1 = input1.trimmingCharacters(in: .whitespaces)
        let v2 = input2.trimmingCharacters(in: .whitespaces)
        guard !v1.isEmpty, (!isDual || !v2.isEmpty) else { return }
        isRunning = true; responseText = nil
        guard let url = tool.buildURL(input1: v1, input2: v2) else {
            await set(error: true, text: "URL không hợp lệ"); return
        }
        do {
            let (data, response) = try await trustAllSession.data(from: url)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? "(không đọc được)"
            await set(error: !(200...299).contains(code), text: "Status: \(code)\n\n\(raw)")
        } catch {
            await set(error: true, text: "Lỗi kết nối:\n\(error.localizedDescription)")
        }
    }

    @MainActor
    private func set(error: Bool, text: String) {
        isError = error; responseText = text; isRunning = false
    }
}
