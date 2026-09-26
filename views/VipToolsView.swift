import SwiftUI
import UIKit

// MARK: - VTTool model

struct VTTool: Identifiable {
    let id: String
    let name: String
    let input: String  // "single" | "dual"
    let label: String
    let label2: String
    let url: String

    init(id: String, name: String, input: String, label: String = "", label2: String = "", url: String) {
        self.id = id; self.name = name; self.input = input
        self.label = label; self.label2 = label2; self.url = url
    }

    static let all: [VTTool] = [
        VTTool(id: "spam_invite",    name: "Spam Kết Bạn FF",       input: "single",
               label: "ID Game FreeFire",
               url: "http://180.93.114.60:3334/sinv?uid={uid}"),
        VTTool(id: "team_dance",     name: "Múa Hành Động Team",     input: "dual",
               label: "Team Code", label2: "ID Game",
               url: "http://180.93.114.60:3334/join?tc={tc}&uid={uid}"),
        VTTool(id: "team5",          name: "Tạo Tổ Đội Team 5",      input: "single",
               label: "ID Game FreeFire",
               url: "http://180.93.114.60:3334/team5?uid={uid}"),
        VTTool(id: "spam_music",     name: "Spam Nhạc Vào Tổ Đội",   input: "single",
               label: "Team Code / ID Game",
               url: "https://haidwngg-production.up.railway.app/join?tc={uid}"),
        VTTool(id: "buff_like",      name: "Buff Like FreeFire",      input: "single",
               label: "ID Game FreeFire",
               url: "http://180.93.114.60:3335/likes?uid={uid}&key=quametlon"),
        VTTool(id: "tool_lag",       name: "Spam Lag Game Tổ Đội",   input: "single",
               label: "ID Game FreeFire",
               url: "https://160.250.135.73:3333/attack?tc={uid}"),
    ]
}

// MARK: - ViewModel

@MainActor
final class BotLinkViewModel: ObservableObject {
    enum LinkState { case loading, unlinked, linking(token: String, botUrl: String), linked(username: String) }

    @Published var state: LinkState = .loading
    @Published var linkError: String? = nil
    @Published var pendingNotice: String? = nil
    static var noticeShownThisSession = false

    var currentKeyCode: String? = nil
    private var pollTask: Task<Void, Never>? = nil

    func checkStatus() async {
        state = .loading
        if let status = await PatchHubService.checkBotLinkStatus(keyCode: currentKeyCode) {
            if status.linked {
                state = .linked(username: status.telegramUsername)
            } else {
                state = .unlinked
            }
        } else {
            state = .unlinked
        }
    }

    func requestLink() async {
        linkError = nil
        guard let result = await PatchHubService.requestBotLinkToken(keyCode: currentKeyCode) else {
            linkError = "Không lấy được link liên kết. Thử lại sau."
            return
        }
        state = .linking(token: result.token, botUrl: result.botUrl)
        startPolling()
    }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            let deadline = Date().addingTimeInterval(5 * 60)
            while !Task.isCancelled, Date() < deadline {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { break }
                if let status = await PatchHubService.checkBotLinkStatus(keyCode: currentKeyCode), status.linked {
                    state = .linked(username: status.telegramUsername)
                    break
                }
            }
        }
    }

    func stopPolling() { pollTask?.cancel(); pollTask = nil }
}

// MARK: - Main View

struct VipToolsView: View {
    @StateObject private var vm = BotLinkViewModel()
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @State private var noticeText: String? = nil
    @State private var selectedTool: VTTool? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                linkSection
                    .padding(.horizontal, 20)
                Spacer(minLength: 40)
            }
        }
        .sheet(item: Binding(
            get: { noticeText.map { NoticeWrapper(text: $0) } },
            set: { if $0 == nil { noticeText = nil } }
        )) { wrapper in
            VipToolsNoticeSheet(text: wrapper.text)
        }
        .sheet(item: $selectedTool) { tool in
            VTToolSheet(tool: tool)
        }
        .task {
            guard licenseGate.isVipEligible else { return }
            vm.currentKeyCode = licenseGate.storedKeyCode
            await vm.checkStatus()
        }
        .onDisappear { vm.stopPolling() }
        .onChange(of: vm.pendingNotice) { notice in
            if let notice {
                BotLinkViewModel.noticeShownThisSession = true
                vm.pendingNotice = nil
                noticeText = notice
            }
        }
    }

    private struct NoticeWrapper: Identifiable {
        let id = UUID()
        let text: String
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                CutShape(cut: 14)
                    .fill(LinearGradient(
                        colors: [AppTheme.neonPurple.opacity(0.28), AppTheme.techGlow.opacity(0.14)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                    .overlay(CutShape(cut: 14)
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

    // MARK: Link Section

    @ViewBuilder
    private var linkSection: some View {
        if !licenseGate.isVipEligible {
            notSupportedCard
        } else {
            switch vm.state {
            case .loading:
                loadingCard

            case .unlinked:
                unlinkCard

            case .linking(let token, let botUrl):
                linkingCard(token: token, botUrl: botUrl)

            case .linked(let username):
                linkedCard(username: username)
            }
        }
    }

    private var notSupportedCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.00, green: 0.38, blue: 0.32).opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 1.00, green: 0.55, blue: 0.20),
                                 Color(red: 1.00, green: 0.30, blue: 0.25)],
                        startPoint: .top, endPoint: .bottom))
            }

            VStack(spacing: 8) {
                Text("Không hỗ trợ")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Text("Vip Tools dành cho key Admin hoặc Seller được cấp VIP.\nKey của bạn không có quyền sử dụng tính năng này.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(24)
        .background(
            CutShape(cut: 20)
                .fill(Color(red: 0.06, green: 0.09, blue: 0.18).opacity(0.95))
                .overlay(CutShape(cut: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(red: 1.00, green: 0.38, blue: 0.32).opacity(0.35),
                                     Color(red: 1.00, green: 0.55, blue: 0.20).opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1))
        )
    }

    private var loadingCard: some View {
        CutShape(cut: 20)
            .fill(Color(red: 0.08, green: 0.12, blue: 0.20).opacity(0.70))
            .frame(height: 180)
            .redacted(reason: .placeholder)
            .shimmering()
    }

    private var unlinkCard: some View {
        VStack(spacing: 20) {
            telegramIcon

            VStack(spacing: 6) {
                Text("Liên kết Telegram Bot")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Text("Liên kết tài khoản Telegram để\nsử dụng các công cụ VIP ngay trong bot.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                    .multilineTextAlignment(.center)
            }

            if let err = vm.linkError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 1.00, green: 0.38, blue: 0.32))
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await vm.requestLink() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Liên kết ngay")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.55, blue: 1.00),
                                 Color(red: 0.40, green: 0.30, blue: 0.95)],
                        startPoint: .leading, endPoint: .trailing),
                    in: CutShape(cut: 13))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            CutShape(cut: 20)
                .fill(Color(red: 0.06, green: 0.09, blue: 0.18).opacity(0.95))
                .overlay(CutShape(cut: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(red: 0.26, green: 0.55, blue: 1.00).opacity(0.40),
                                     Color(red: 0.48, green: 0.37, blue: 1.00).opacity(0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1))
        )
    }

    private func linkingCard(token: String, botUrl: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.15, green: 0.55, blue: 1.00).opacity(0.12))
                    .frame(width: 72, height: 72)
                ProgressView()
                    .tint(Color(red: 0.26, green: 0.55, blue: 1.00))
                    .scaleEffect(1.4)
            }

            VStack(spacing: 6) {
                Text("Đang chờ liên kết...")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Text("Bấm nút bên dưới để mở Telegram bot\nvà hoàn tất liên kết.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                    .multilineTextAlignment(.center)
            }

            Button {
                openTelegram(token: token, fallbackUrl: botUrl)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Mở bot Telegram")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.55, blue: 1.00),
                                 Color(red: 0.40, green: 0.30, blue: 0.95)],
                        startPoint: .leading, endPoint: .trailing),
                    in: CutShape(cut: 13))
            }
            .buttonStyle(.plain)

            Button {
                vm.stopPolling()
                Task { await vm.checkStatus() }
            } label: {
                Text("Hủy")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            CutShape(cut: 20)
                .fill(Color(red: 0.06, green: 0.09, blue: 0.18).opacity(0.95))
                .overlay(CutShape(cut: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(red: 0.26, green: 0.55, blue: 1.00).opacity(0.40),
                                     Color(red: 0.48, green: 0.37, blue: 1.00).opacity(0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1))
        )
    }

    // MARK: Linked card — shows tool buttons

    private func linkedCard(username: String) -> some View {
        VStack(spacing: 16) {
            // Compact linked status header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.10, green: 0.72, blue: 0.42).opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.18, green: 0.84, blue: 0.44))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Đã liên kết")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    if !username.isEmpty {
                        Text("@\(username)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.26, green: 0.55, blue: 1.00))
                    }
                }
                Spacer()
                Button {
                    Task { await vm.checkStatus() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                CutShape(cut: 12)
                    .fill(Color(red: 0.08, green: 0.14, blue: 0.22))
                    .overlay(CutShape(cut: 12)
                        .strokeBorder(Color(red: 0.18, green: 0.84, blue: 0.44).opacity(0.25), lineWidth: 1))
            )

            // Section title
            HStack {
                Text("Tool Free Fire")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                Text("Chọn công cụ")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                Spacer()
            }
            .padding(.horizontal, 4)

            // Tool buttons grid
            VStack(spacing: 10) {
                ForEach(VTTool.all) { tool in
                    toolButton(tool)
                }
            }

            // Open bot secondary button
            Button {
                openTelegram(token: nil, fallbackUrl: "https://t.me/cheatstorevn_bot")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Mở bot Telegram")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    CutShape(cut: 10)
                        .fill(Color(red: 0.08, green: 0.12, blue: 0.20))
                        .overlay(CutShape(cut: 10)
                            .strokeBorder(Color(red: 0.26, green: 0.40, blue: 0.70).opacity(0.30), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            CutShape(cut: 20)
                .fill(Color(red: 0.06, green: 0.09, blue: 0.18).opacity(0.95))
                .overlay(CutShape(cut: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.84, blue: 0.44).opacity(0.30),
                                     Color(red: 0.10, green: 0.62, blue: 0.35).opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1))
        )
    }

    private func toolButton(_ tool: VTTool) -> some View {
        Button {
            selectedTool = tool
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    CutShape(cut: 8)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.15, green: 0.55, blue: 1.00).opacity(0.20),
                                     Color(red: 0.40, green: 0.30, blue: 0.95).opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Image(systemName: toolIcon(tool.id))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(red: 0.26, green: 0.55, blue: 1.00),
                                     Color(red: 0.48, green: 0.37, blue: 1.00)],
                            startPoint: .top, endPoint: .bottom))
                }
                Text(tool.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.40, green: 0.50, blue: 0.70))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                CutShape(cut: 11)
                    .fill(Color(red: 0.08, green: 0.13, blue: 0.22))
                    .overlay(CutShape(cut: 11)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(red: 0.26, green: 0.55, blue: 1.00).opacity(0.25),
                                         Color(red: 0.48, green: 0.37, blue: 1.00).opacity(0.10)],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func toolIcon(_ id: String) -> String {
        switch id {
        case "spam_invite":  return "person.badge.plus"
        case "team_dance":   return "figure.dance"
        case "team5":        return "person.3.fill"
        case "spam_music":   return "music.note"
        case "buff_like":    return "heart.fill"
        default:             return "bolt.fill"
        }
    }

    private func openTelegram(token: String?, fallbackUrl: String) {
        let botName = "cheatstorevn_bot"
        let tgUrl: URL?
        if let token, !token.isEmpty {
            tgUrl = URL(string: "tg://resolve?domain=\(botName)&start=\(token)")
        } else {
            tgUrl = URL(string: "tg://resolve?domain=\(botName)")
        }
        if let url = tgUrl {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success, let fallback = URL(string: fallbackUrl) {
                    UIApplication.shared.open(fallback)
                }
            }
        } else if let fallback = URL(string: fallbackUrl) {
            UIApplication.shared.open(fallback)
        }
    }

    private var telegramIcon: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.15, green: 0.55, blue: 1.00).opacity(0.18),
                             Color(red: 0.40, green: 0.30, blue: 0.95).opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 72, height: 72)
            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 0.26, green: 0.55, blue: 1.00),
                             Color(red: 0.48, green: 0.37, blue: 1.00)],
                    startPoint: .top, endPoint: .bottom))
        }
    }
}

// MARK: - VTTool Input Sheet

struct VTToolSheet: View {
    let tool: VTTool
    @Environment(\.dismiss) private var dismiss
    @State private var input1 = ""
    @State private var input2 = ""
    @State private var isRunning = false
    @State private var result: String? = nil
    @State private var isSuccess: Bool? = nil

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.12).ignoresSafeArea()
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 22)

                ScrollView {
                    VStack(spacing: 24) {
                        // Title
                        VStack(spacing: 6) {
                            Text(tool.name)
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            Text("Tool Free Fire")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
                        }

                        // Input fields
                        VStack(spacing: 12) {
                            if tool.input == "dual" {
                                inputField(placeholder: tool.label, text: $input1)
                                inputField(placeholder: tool.label2, text: $input2)
                            } else {
                                inputField(placeholder: tool.label, text: $input1)
                            }
                        }

                        // Result
                        if let result {
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: isSuccess == true ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundStyle(isSuccess == true
                                            ? Color(red: 0.18, green: 0.84, blue: 0.44)
                                            : Color(red: 1.00, green: 0.45, blue: 0.35))
                                    Text(isSuccess == true ? "Thành công" : "Kết quả")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                Text(result)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(red: 0.85, green: 0.88, blue: 0.96))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(14)
                            .background(
                                CutShape(cut: 12)
                                    .fill(Color(red: 0.08, green: 0.13, blue: 0.22))
                                    .overlay(CutShape(cut: 12)
                                        .strokeBorder(
                                            (isSuccess == true
                                             ? Color(red: 0.18, green: 0.84, blue: 0.44)
                                             : Color(red: 1.00, green: 0.45, blue: 0.35)).opacity(0.30),
                                            lineWidth: 1))
                            )
                        }

                        // Run button
                        Button {
                            Task { await runTool() }
                        } label: {
                            HStack(spacing: 8) {
                                if isRunning {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                Text(isRunning ? "Đang chạy..." : "Chạy")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.15, green: 0.55, blue: 1.00),
                                             Color(red: 0.40, green: 0.30, blue: 0.95)],
                                    startPoint: .leading, endPoint: .trailing),
                                in: CutShape(cut: 13))
                            .opacity(canRun ? 1 : 0.45)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canRun || isRunning)

                        Button { dismiss() } label: {
                            Text("Đóng")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private var canRun: Bool {
        if tool.input == "dual" {
            return !input1.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !input2.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return !input1.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func inputField(placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(placeholder)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
            TextField("", text: text)
                .placeholder(when: text.wrappedValue.isEmpty) {
                    Text("Nhập \(placeholder.lowercased())...")
                        .foregroundStyle(Color(red: 0.35, green: 0.42, blue: 0.58))
                }
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .keyboardType(.numberPad)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    CutShape(cut: 10)
                        .fill(Color(red: 0.08, green: 0.13, blue: 0.22))
                        .overlay(CutShape(cut: 10)
                            .strokeBorder(Color(red: 0.26, green: 0.40, blue: 0.70).opacity(0.35), lineWidth: 1))
                )
        }
    }

    @MainActor
    private func runTool() async {
        isRunning = true
        result = nil
        let uid = input1.trimmingCharacters(in: .whitespaces)
        let tc  = input2.trimmingCharacters(in: .whitespaces)

        var urlStr = tool.url
            .replacingOccurrences(of: "{uid}", with: uid)
            .replacingOccurrences(of: "{tc}", with: tc)

        guard let url = URL(string: urlStr) else {
            result = "URL không hợp lệ."
            isSuccess = false
            isRunning = false
            return
        }

        do {
            var req = URLRequest(url: url, timeoutInterval: 20)
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, resp) = try await URLSession.shared.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let text = String(data: data, encoding: .utf8) ?? ""

            // Try JSON parse for message field
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let msg = json["message"] as? String
                    ?? json["msg"] as? String
                    ?? json["result"] as? String
                    ?? json["status"] as? String
                    ?? text
                isSuccess = status >= 200 && status < 300
                result = msg
            } else {
                isSuccess = status >= 200 && status < 300
                result = text.isEmpty ? "Thành công (status \(status))" : text
            }
        } catch {
            isSuccess = false
            result = "Lỗi kết nối: \(error.localizedDescription)"
        }
        isRunning = false
    }
}

// MARK: - Shimmer modifier

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

    @ViewBuilder
    func placeholder<Content: View>(when shouldShow: Bool, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { placeholder() }
            self
        }
    }
}

// MARK: - Vip Tools Notice Sheet

struct VipToolsNoticeSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.12).ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 22)

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Thông báo")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(.white)
                            Text("Vip Tools")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
                        }

                        Text(text)
                            .font(.system(size: 15))
                            .foregroundStyle(Color(red: 0.85, green: 0.88, blue: 0.96))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)

                        Button {
                            dismiss()
                        } label: {
                            Text("Đã hiểu")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.neonPurple, AppTheme.techGlow.opacity(0.85)],
                                        startPoint: .leading, endPoint: .trailing),
                                    in: CutShape(cut: 14))
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}
