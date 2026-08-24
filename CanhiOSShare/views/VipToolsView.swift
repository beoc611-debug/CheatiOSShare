import SwiftUI

// MARK: - SSL bypass for self-signed certs on tool API servers

private class TrustAllDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

// MARK: - Main View

private enum VipSheet: Identifiable {
    case buffLike, spamInvite, teamDance
    var id: Self { self }
}

struct VipToolsView: View {
    @State private var activeSheet: VipSheet? = nil

    var body: some View {
        ZStack {
            TechBackground()

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
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .buffLike:   BuffLikeSheet()
            case .spamInvite: SpamInviteSheet()
            case .teamDance:  TeamDanceSheet()
            }
        }
    }

    // MARK: - Header

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

    // MARK: - Tools list (horizontal cards)

    private var toolsList: some View {
        VStack(spacing: 10) {
            // Buff Like FreeFire
            ToolRowCard(
                icon: "heart.fill",
                iconGradient: [Color(red: 1.00, green: 0.40, blue: 0.15), Color(red: 0.80, green: 0.08, blue: 0.08)],
                title: "Buff Like FreeFire",
                subtitle: "Tăng Like · Nhập ID game · Chạy ngay",
                isLive: true
            ) { activeSheet = .buffLike }

            // Spam Kết Bạn FreeFire
            ToolRowCard(
                icon: "person.2.fill",
                iconGradient: [Color(red: 0.20, green: 0.72, blue: 1.00), Color(red: 0.08, green: 0.42, blue: 0.90)],
                title: "Spam Kết Bạn FF",
                subtitle: "Gửi lời mời kết bạn · Nhập ID · Tiến hành spam",
                isLive: true
            ) { activeSheet = .spamInvite }

            // Múa Hành Động Team
            ToolRowCard(
                icon: "figure.dance",
                iconGradient: [Color(red: 0.10, green: 0.85, blue: 0.45), Color(red: 0.05, green: 0.60, blue: 0.28)],
                title: "Múa Hành Động Team",
                subtitle: "Nhập Team Code + ID · Tiến hành múa",
                isLive: true
            ) { activeSheet = .teamDance }

            // Placeholders
            ToolRowCard(icon: "bolt.shield.fill",
                        iconGradient: [Color(red: 0.55, green: 0.20, blue: 0.80), Color(red: 0.35, green: 0.10, blue: 0.60)],
                        title: "Sắp ra mắt", subtitle: "Đang phát triển", isLive: false, action: nil)
        }
    }
}

// MARK: - Row Card

struct ToolRowCard: View {
    let icon: String
    let iconGradient: [Color]
    let title: String
    let subtitle: String
    let isLive: Bool
    let action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(
                            colors: iconGradient.map { $0.opacity(0.22) },
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(LinearGradient(
                            colors: iconGradient, startPoint: .top, endPoint: .bottom))
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(red: 0.50, green: 0.58, blue: 0.75))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Right badge + chevron
                if isLive {
                    Text("LIVE")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundStyle(iconGradient[0])
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(iconGradient[0].opacity(0.14), in: Capsule())
                        .overlay(Capsule().strokeBorder(iconGradient[0].opacity(0.30), lineWidth: 1))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.52, blue: 0.70))
                } else {
                    Text("SỚM")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Color(red: 0.38, green: 0.46, blue: 0.62))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.12, green: 0.16, blue: 0.26), in: Capsule())
                }
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
                                    colors: isLive
                                        ? [iconGradient[0].opacity(0.45), iconGradient[1].opacity(0.18)]
                                        : [Color(red: 0.18, green: 0.24, blue: 0.38).opacity(0.50), .clear],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(isLive ? 1.0 : 0.48)
        .disabled(!isLive)
    }
}

// MARK: - Shared API session (SSL bypass)

private let trustAllSession: URLSession = {
    URLSession(configuration: .default, delegate: TrustAllDelegate(), delegateQueue: nil)
}()

// MARK: - Buff Like Sheet

struct BuffLikeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var uid = ""
    @State private var isRunning = false
    @State private var responseText: String? = nil
    @State private var isError = false

    var body: some View {
        ToolSheet(
            icon: "heart.fill",
            iconGradient: [Color(red: 1.00, green: 0.40, blue: 0.15), Color(red: 0.80, green: 0.08, blue: 0.08)],
            title: "Buff Like FreeFire",
            subtitle: "Nhập ID game để tăng Like",
            inputLabel: "ID Game FreeFire",
            inputPlaceholder: "Nhập ID game...",
            runLabel: "Chạy ngay",
            uid: $uid,
            isRunning: $isRunning,
            responseText: $responseText,
            isError: $isError,
            onRun: runBuff
        )
    }

    private func runBuff() async {
        let trimmed = uid.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isRunning = true; responseText = nil
        let urlStr = "https://180.93.114.60:3636/like?uid=\(trimmed)&key=quametlon"
        await callAPI(urlStr)
    }

    private func callAPI(_ urlStr: String) async {
        guard let url = URL(string: urlStr) else {
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

    @MainActor private func set(error: Bool, text: String) {
        isError = error; responseText = text; isRunning = false
    }
}

// MARK: - Spam Invite Sheet

struct SpamInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var uid = ""
    @State private var isRunning = false
    @State private var responseText: String? = nil
    @State private var isError = false

    var body: some View {
        ToolSheet(
            icon: "person.2.fill",
            iconGradient: [Color(red: 0.20, green: 0.72, blue: 1.00), Color(red: 0.08, green: 0.42, blue: 0.90)],
            title: "Spam Kết Bạn FF",
            subtitle: "Nhập ID để gửi lời mời kết bạn",
            inputLabel: "ID Game FreeFire",
            inputPlaceholder: "Nhập ID game...",
            runLabel: "Tiến hành spam",
            uid: $uid,
            isRunning: $isRunning,
            responseText: $responseText,
            isError: $isError,
            onRun: runSpam
        )
    }

    private func runSpam() async {
        let trimmed = uid.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isRunning = true; responseText = nil
        let urlStr = "https://180.93.114.60:1717/sinv?uid=\(trimmed)"
        await callAPI(urlStr)
    }

    private func callAPI(_ urlStr: String) async {
        guard let url = URL(string: urlStr) else {
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

    @MainActor private func set(error: Bool, text: String) {
        isError = error; responseText = text; isRunning = false
    }
}

// MARK: - Team Dance Sheet

struct TeamDanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var teamCode = ""
    @State private var uids = ""
    @State private var isRunning = false
    @State private var responseText: String? = nil
    @State private var isError = false

    private let gradient: [Color] = [
        Color(red: 0.10, green: 0.85, blue: 0.45),
        Color(red: 0.05, green: 0.60, blue: 0.28)
    ]

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
                                        colors: gradient.map { $0.opacity(0.20) },
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "figure.dance")
                                    .font(.system(size: 21, weight: .bold))
                                    .foregroundStyle(LinearGradient(
                                        colors: gradient, startPoint: .top, endPoint: .bottom))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Múa Hành Động Team")
                                    .font(.system(size: 19, weight: .black))
                                    .foregroundStyle(.white)
                                Text("Nhập Team Code + ID người múa")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // Input 1: Team Code
                        inputField(
                            label: "Team Code",
                            placeholder: "Nhập ID team...",
                            icon: "person.3.fill",
                            text: $teamCode,
                            useNumberPad: true
                        )

                        // Input 2: UIDs (có thể nhiều, cách nhau dấu phẩy)
                        inputField(
                            label: "ID Game (nhiều ID cách nhau bằng dấu phẩy)",
                            placeholder: "VD: 123456,789012,828822",
                            icon: "person.fill",
                            text: $uids,
                            useNumberPad: false
                        )

                        // Run button
                        let canRun = !teamCode.trimmingCharacters(in: .whitespaces).isEmpty
                                  && !uids.trimmingCharacters(in: .whitespaces).isEmpty
                        Button {
                            Task { await runDance() }
                        } label: {
                            HStack(spacing: 8) {
                                if isRunning {
                                    ProgressView().tint(.white).scaleEffect(0.82)
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                Text(isRunning ? "Đang múa..." : "Tiến hành múa")
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
                                                colors: gradient,
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
    private func inputField(label: String, placeholder: String, icon: String,
                            text: Binding<String>, useNumberPad: Bool) -> some View {
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
                    Text(placeholder)
                        .foregroundColor(Color(red: 0.32, green: 0.40, blue: 0.60))
                )
                .keyboardType(useNumberPad ? .numberPad : .default)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .tint(gradient[0])
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

    private func runDance() async {
        let tc = teamCode.trimmingCharacters(in: .whitespaces)
        let uid = uids.trimmingCharacters(in: .whitespaces)
        guard !tc.isEmpty, !uid.isEmpty else { return }
        isRunning = true; responseText = nil
        let urlStr = "https://180.93.114.60:1717/join?tc=\(tc)&uid=\(uid)"
        guard let url = URL(string: urlStr) else {
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

    @MainActor private func set(error: Bool, text: String) {
        isError = error; responseText = text; isRunning = false
    }
}

// MARK: - Shared Sheet UI

struct ToolSheet: View {
    let icon: String
    let iconGradient: [Color]
    let title: String
    let subtitle: String
    let inputLabel: String
    let inputPlaceholder: String
    let runLabel: String
    @Binding var uid: String
    @Binding var isRunning: Bool
    @Binding var responseText: String?
    @Binding var isError: Bool
    let onRun: () async -> Void

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
                                        colors: iconGradient.map { $0.opacity(0.20) },
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 48, height: 48)
                                Image(systemName: icon)
                                    .font(.system(size: 21, weight: .bold))
                                    .foregroundStyle(LinearGradient(
                                        colors: iconGradient, startPoint: .top, endPoint: .bottom))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.system(size: 19, weight: .black))
                                    .foregroundStyle(.white)
                                Text(subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // Input label
                        VStack(alignment: .leading, spacing: 8) {
                            Text(inputLabel)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                                .padding(.horizontal, 20)

                            HStack(spacing: 10) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(red: 0.42, green: 0.50, blue: 0.70))
                                TextField("", text: $uid, prompt:
                                    Text(inputPlaceholder)
                                        .foregroundColor(Color(red: 0.32, green: 0.40, blue: 0.60))
                                )
                                .keyboardType(.numberPad)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .tint(iconGradient[0])
                                if !uid.isEmpty {
                                    Button { uid = "" } label: {
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

                        // Run button
                        Button {
                            Task { await onRun() }
                        } label: {
                            HStack(spacing: 8) {
                                if isRunning {
                                    ProgressView().tint(.white).scaleEffect(0.82)
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                Text(isRunning ? "Đang chạy..." : runLabel)
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Group {
                                    if uid.trimmingCharacters(in: .whitespaces).isEmpty || isRunning {
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .fill(Color(red: 0.14, green: 0.16, blue: 0.24))
                                    } else {
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .fill(LinearGradient(
                                                colors: iconGradient,
                                                startPoint: .leading, endPoint: .trailing))
                                    }
                                }
                            )
                        }
                        .disabled(uid.trimmingCharacters(in: .whitespaces).isEmpty || isRunning)
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
}
