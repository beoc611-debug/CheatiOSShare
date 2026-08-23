import SwiftUI

// MARK: - SSL bypass for self-signed cert on the buff API server

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

struct VipToolsView: View {
    @State private var showBuffLike = false

    var body: some View {
        ZStack {
            TechBackground()

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)

                    toolsGrid
                        .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
            }
        }
        .sheet(isPresented: $showBuffLike) {
            BuffLikeSheet()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.neonPurple.opacity(0.30), AppTheme.techGlow.opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppTheme.neonPurple.opacity(0.45), lineWidth: 1)
                    )
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.techGlow, AppTheme.neonPurple],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Vip Tools")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.26, green: 0.55, blue: 1.00),
                                     Color(red: 0.48, green: 0.37, blue: 1.00)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text("Công cụ cao cấp · Độc quyền VIP")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
            }

            Spacer()
        }
    }

    // MARK: - Grid

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var toolsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 14) {
            // Buff Like FreeFire — real tool
            VipToolCard(
                icon: "heart.fill",
                title: "Buff Like FF",
                subtitle: "FreeFire · Tăng Like",
                gradient: [Color(red: 1.00, green: 0.30, blue: 0.20), Color(red: 0.80, green: 0.10, blue: 0.10)],
                isAvailable: true
            ) {
                showBuffLike = true
            }

            // Placeholders
            VipToolCard(icon: "lock.shield.fill", title: "Sắp ra mắt", subtitle: "Đang phát triển",
                        gradient: [Color(red: 0.48, green: 0.37, blue: 1.00), Color(red: 0.28, green: 0.17, blue: 0.80)],
                        isAvailable: false, action: nil)
            VipToolCard(icon: "bolt.shield.fill", title: "Sắp ra mắt", subtitle: "Đang phát triển",
                        gradient: [Color(red: 0.10, green: 0.55, blue: 0.80), Color(red: 0.06, green: 0.35, blue: 0.60)],
                        isAvailable: false, action: nil)
            VipToolCard(icon: "cpu.fill", title: "Sắp ra mắt", subtitle: "Đang phát triển",
                        gradient: [Color(red: 0.55, green: 0.20, blue: 0.80), Color(red: 0.35, green: 0.10, blue: 0.60)],
                        isAvailable: false, action: nil)
        }
    }
}

// MARK: - Tool Card

struct VipToolCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    let isAvailable: Bool
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: gradient.map { $0.opacity(0.25) },
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom))
                }

                VStack(alignment: .leading, spacing: 2) {
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

                HStack {
                    Spacer()
                    if isAvailable {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(gradient[0])
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(red: 0.40, green: 0.48, blue: 0.65))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [gradient[0].opacity(isAvailable ? 0.55 : 0.25),
                                             gradient[1].opacity(isAvailable ? 0.25 : 0.10)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(isAvailable ? 1.0 : 0.55)
    }
}

// MARK: - Buff Like Sheet

struct BuffLikeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var uid = ""
    @State private var isRunning = false
    @State private var responseText: String? = nil
    @State private var isError = false

    private let delegate = TrustAllDelegate()

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle bar
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 38, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color(red: 1.00, green: 0.30, blue: 0.20).opacity(0.25),
                                                 Color(red: 0.80, green: 0.10, blue: 0.10).opacity(0.15)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(LinearGradient(
                                        colors: [Color(red: 1.00, green: 0.40, blue: 0.20),
                                                 Color(red: 1.00, green: 0.15, blue: 0.10)],
                                        startPoint: .top, endPoint: .bottom))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Buff Like FreeFire")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(.white)
                                Text("Nhập ID game để tăng Like")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ID Game FreeFire")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                                .padding(.horizontal, 20)

                            HStack(spacing: 10) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color(red: 0.45, green: 0.53, blue: 0.72))
                                TextField("", text: $uid, prompt:
                                    Text("Nhập ID game...").foregroundColor(Color(red: 0.35, green: 0.43, blue: 0.62))
                                )
                                .keyboardType(.numberPad)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .tint(Color(red: 1.00, green: 0.35, blue: 0.15))

                                if !uid.isEmpty {
                                    Button { uid = "" } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color(red: 0.40, green: 0.48, blue: 0.65))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(red: 0.08, green: 0.11, blue: 0.18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(Color(red: 0.20, green: 0.28, blue: 0.45), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        }

                        // Run button
                        Button {
                            Task { await runBuff() }
                        } label: {
                            HStack(spacing: 10) {
                                if isRunning {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                Text(isRunning ? "Đang chạy..." : "Chạy ngay")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                Group {
                                    if uid.trimmingCharacters(in: .whitespaces).isEmpty || isRunning {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color(red: 0.25, green: 0.18, blue: 0.18))
                                    } else {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(LinearGradient(
                                                colors: [Color(red: 1.00, green: 0.32, blue: 0.10),
                                                         Color(red: 0.85, green: 0.12, blue: 0.08)],
                                                startPoint: .leading, endPoint: .trailing
                                            ))
                                    }
                                }
                            )
                        }
                        .disabled(uid.trimmingCharacters(in: .whitespaces).isEmpty || isRunning)
                        .padding(.horizontal, 20)

                        // Response
                        if let text = responseText {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(isError
                                            ? Color(red: 1.00, green: 0.30, blue: 0.25)
                                            : Color(red: 0.20, green: 0.85, blue: 0.45))
                                    Text(isError ? "Lỗi" : "Phản hồi")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(isError
                                            ? Color(red: 1.00, green: 0.30, blue: 0.25)
                                            : Color(red: 0.20, green: 0.85, blue: 0.45))
                                }

                                Text(text)
                                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.90))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(red: 0.06, green: 0.09, blue: 0.16))
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
        .animation(.easeInOut(duration: 0.25), value: responseText)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - API Call

    private func runBuff() async {
        let trimmed = uid.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isRunning = true
        responseText = nil

        let urlString = "https://180.93.114.60:3636/like?uid=\(trimmed)&key=quametlon"
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                isError = true
                responseText = "URL không hợp lệ"
                isRunning = false
            }
            return
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        do {
            let (data, response) = try await session.data(from: url)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? "(không đọc được)"

            await MainActor.run {
                isError = !(200...299).contains(statusCode)
                responseText = "Status: \(statusCode)\n\n\(raw)"
                isRunning = false
            }
        } catch {
            await MainActor.run {
                isError = true
                responseText = "Lỗi kết nối:\n\(error.localizedDescription)"
                isRunning = false
            }
        }
    }
}
