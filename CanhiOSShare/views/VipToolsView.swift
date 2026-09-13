import SwiftUI
import UIKit

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
        .task {
            guard licenseGate.isAdminKey else { return }
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.06, green: 0.09, blue: 0.18).opacity(0.95))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(red: 1.00, green: 0.38, blue: 0.32).opacity(0.35),
                                     Color(red: 1.00, green: 0.55, blue: 0.20).opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1))
        )
    }

    private var loadingCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.06, green: 0.09, blue: 0.18).opacity(0.95))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.06, green: 0.09, blue: 0.18).opacity(0.95))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(red: 0.26, green: 0.55, blue: 1.00).opacity(0.40),
                                     Color(red: 0.48, green: 0.37, blue: 1.00).opacity(0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1))
        )
    }

    private func linkedCard(username: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.10, green: 0.72, blue: 0.42).opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 0.18, green: 0.84, blue: 0.44),
                                 Color(red: 0.10, green: 0.62, blue: 0.35)],
                        startPoint: .top, endPoint: .bottom))
            }

            VStack(spacing: 6) {
                Text("Đã liên kết")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                if !username.isEmpty {
                    Text("@\(username)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.26, green: 0.55, blue: 1.00))
                }
                Text("Sử dụng bot Telegram để chạy\ncác công cụ VIP của bạn.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                    .multilineTextAlignment(.center)
            }

            Button {
                openTelegram(token: nil, fallbackUrl: "https://t.me/cheatstorevn_bot")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Mở bot")
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
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                Task { await vm.checkStatus() }
            } label: {
                Text("Làm mới")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.06, green: 0.09, blue: 0.18).opacity(0.95))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.84, blue: 0.44).opacity(0.40),
                                     Color(red: 0.10, green: 0.62, blue: 0.35).opacity(0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1))
        )
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
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
