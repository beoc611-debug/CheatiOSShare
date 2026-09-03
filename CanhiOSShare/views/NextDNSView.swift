import AVKit
import SafariServices
import SwiftUI

// MARK: - NextDNS Shield Shape (matches NextDNS brand logo)
private struct NextDNSShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // Top-left ear
        p.move(to: CGPoint(x: w * 0.50, y: h * 0.07))
        p.addCurve(to: CGPoint(x: w * 0.02, y: h * 0.22),
                   control1: CGPoint(x: w * 0.22, y: h * 0.00),
                   control2: CGPoint(x: w * 0.02, y: h * 0.10))
        // Left side down
        p.addCurve(to: CGPoint(x: w * 0.12, y: h * 0.76),
                   control1: CGPoint(x: w * 0.02, y: h * 0.52),
                   control2: CGPoint(x: w * 0.04, y: h * 0.65))
        // Bottom point
        p.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.98),
                   control1: CGPoint(x: w * 0.22, y: h * 0.89),
                   control2: CGPoint(x: w * 0.38, y: h * 0.98))
        // Right bottom
        p.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.76),
                   control1: CGPoint(x: w * 0.62, y: h * 0.98),
                   control2: CGPoint(x: w * 0.78, y: h * 0.89))
        // Right side up
        p.addCurve(to: CGPoint(x: w * 0.98, y: h * 0.22),
                   control1: CGPoint(x: w * 0.96, y: h * 0.65),
                   control2: CGPoint(x: w * 0.98, y: h * 0.52))
        // Top-right ear back to center
        p.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.07),
                   control1: CGPoint(x: w * 0.98, y: h * 0.10),
                   control2: CGPoint(x: w * 0.78, y: h * 0.00))
        p.closeSubpath()
        return p
    }
}

private struct NextDNSShieldIcon: View {
    var size: CGFloat = 24
    var isActive: Bool = false
    var active: Color = Color(red: 0.10, green: 0.85, blue: 0.55)
    var c1: Color = Color(red: 0.20, green: 0.55, blue: 1.00)
    var c2: Color = Color(red: 0.10, green: 0.78, blue: 1.00)

    var body: some View {
        NextDNSShieldShape()
            .fill(LinearGradient(
                colors: isActive ? [active, Color(red: 0.2, green: 1.0, blue: 0.65)] : [c1, c2],
                startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .shadow(color: (isActive ? active : c1).opacity(0.55), radius: size * 0.3)
    }
}

private struct SafariInstallView: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.delegate = context.coordinator
        vc.preferredControlTintColor = UIColor(red: 0.20, green: 0.70, blue: 1.00, alpha: 1)
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { onDismiss() }
        func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                controller.dismiss(animated: true)
                self.onDismiss()
            }
        }
    }
}

@MainActor
final class NextDNSViewModel: ObservableObject {
    static var noticeShownThisSession = false
    @Published var profiles: [PatchHubService.DNSProfile] = []
    @Published var isLoading = false
    @Published var loadError: String? = nil
    @Published var pendingNotice: String? = nil

    func load() async {
        isLoading = true; loadError = nil
        do {
            let result = try await PatchHubService.fetchDNSProfiles()
            profiles = result.profiles
            if !NextDNSViewModel.noticeShownThisSession, let notice = result.notice, !notice.isEmpty {
                pendingNotice = notice
            }
        }
        catch { loadError = "Không tải được danh sách DNS" }
        isLoading = false
    }
}

struct NextDNSView: View {
    @StateObject private var vm  = NextDNSViewModel()
    @StateObject private var dns = NEDNSManager.shared
    @State private var safariURL: URL? = nil
    @State private var showInstallTip = false
    @State private var toastMsg: String? = nil
    @State private var activatingID: String? = nil
    @State private var noticeText: String? = nil
    @State private var videoURL: URL? = nil

    private let accent = Color(red: 0.20, green: 0.70, blue: 1.00)
    private let green  = Color(red: 0.10, green: 0.85, blue: 0.55)
    private let purple = Color(red: 0.55, green: 0.20, blue: 1.00)

    private struct NoticeWrapper: Identifiable {
        let id = UUID(); let text: String
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)
                    content.padding(.horizontal, 14)
                    Spacer(minLength: 40)
                }
            }
            .refreshable { await vm.load(); await dns.load() }

            // Toast
            if let msg = toastMsg {
                Text(msg)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Color(red: 0.08, green: 0.12, blue: 0.24), in: Capsule())
                    .overlay(Capsule().strokeBorder(accent.opacity(0.3), lineWidth: 1))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await vm.load(); await dns.load() }
        // Notice sheet
        .sheet(item: Binding(
            get: { noticeText.map { NoticeWrapper(text: $0) } },
            set: { if $0 == nil { noticeText = nil } }
        )) { wrapper in
            DNSNoticeSheet(text: wrapper.text, accent: accent)
        }
        // Video player sheet
        .sheet(isPresented: Binding(get: { videoURL != nil }, set: { if !$0 { videoURL = nil } })) {
            if let url = videoURL {
                DNSVideoPlayerView(url: url) { videoURL = nil }
                    .ignoresSafeArea()
            }
        }
        // Safari download sheet
        .sheet(isPresented: Binding(get: { safariURL != nil }, set: { if !$0 { safariURL = nil } })) {
            if let url = safariURL {
                SafariInstallView(url: url) { safariURL = nil }.ignoresSafeArea()
            }
        }
        .onChange(of: vm.pendingNotice) { notice in
            if let notice {
                NextDNSViewModel.noticeShownThisSession = true
                vm.pendingNotice = nil
                noticeText = notice
            }
        }
        .overlay(alignment: .center) {
            if showInstallTip {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                        .onTapGesture { showInstallTip = false }
                    VStack(spacing: 0) {
                        Text("Cách cài DNS Profile")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .padding(.top, 20).padding(.horizontal, 20)
                        Text("1. Bấm nút Tải để tải\n2. Cửa sổ hiện lên → bấm \"Cho phép\"\n3. Cài đặt → Đã tải về → Cài đặt profile\n4. Cài đặt → VPN & Quản lý thiết bị → Cài đặt")
                            .font(.system(size: 13.5)).foregroundStyle(Color(red: 0.75, green: 0.88, blue: 1.0))
                            .multilineTextAlignment(.center).lineSpacing(3)
                            .padding(.horizontal, 20).padding(.vertical, 14)
                        Rectangle().fill(accent.opacity(0.18)).frame(height: 1)
                        Button { showInstallTip = false } label: {
                            Text("Đã hiểu")
                                .font(.system(size: 16, weight: .semibold)).foregroundStyle(accent)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.06, green: 0.10, blue: 0.22))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(accent.opacity(0.28), lineWidth: 1)))
                    .padding(.horizontal, 36)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [accent.opacity(0.25), green.opacity(0.12)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accent.opacity(0.35), lineWidth: 1))
                NextDNSShieldIcon(size: 26)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Next DNS")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [accent, green], startPoint: .leading, endPoint: .trailing))
                Text("DNS Profile · Chống ban · Bảo mật")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
            }
            Spacer()
            Button { showInstallTip = true } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 18)).foregroundStyle(accent.opacity(0.7))
            }.buttonStyle(.plain)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.profiles.isEmpty {
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.08, green: 0.12, blue: 0.20).opacity(0.60))
                        .frame(height: 90).redacted(reason: .placeholder)
                }
            }
        } else if let err = vm.loadError {
            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark").font(.system(size: 32)).foregroundStyle(accent.opacity(0.7))
                Text(err).font(.system(size: 13)).foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80)).multilineTextAlignment(.center)
                Button { Task { await vm.load(); await dns.load() } } label: {
                    Text("Thử lại").font(.system(size: 13, weight: .semibold)).foregroundStyle(accent)
                        .padding(.horizontal, 18).padding(.vertical, 8).background(accent.opacity(0.12), in: Capsule())
                }
            }.padding(.vertical, 48).frame(maxWidth: .infinity)
        } else if vm.profiles.isEmpty {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(accent.opacity(0.10)).frame(width: 72, height: 72)
                    NextDNSShieldIcon(size: 34)
                }
                Text("Chưa có DNS Profile").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text("Admin chưa thêm profile nào.\nVui lòng quay lại sau.")
                    .font(.system(size: 13)).foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80)).multilineTextAlignment(.center)
            }.padding(.vertical, 52).frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 10) {
                // Status bar
                HStack(spacing: 8) {
                    Circle()
                        .fill(dns.isEnabled ? green : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Text(dns.isEnabled ? "DNS đang hoạt động" : "Đang dùng DNS mặc định")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(dns.isEnabled ? green.opacity(0.9) : Color(red: 0.50, green: 0.62, blue: 0.80))
                    Spacer()
                    if dns.isEnabled {
                        Button { Task { await deactivate() } } label: {
                            Text("Tắt DNS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.40))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color(red: 1.0, green: 0.3, blue: 0.25).opacity(0.15), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color(red: 1.0, green: 0.3, blue: 0.25).opacity(0.3), lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    (dns.isEnabled ? green.opacity(0.06) : accent.opacity(0.05)),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder((dns.isEnabled ? green : accent).opacity(0.18), lineWidth: 1))
                .padding(.bottom, 4)

                ForEach(vm.profiles) { profile in
                    DNSProfileCard(
                        profile: profile,
                        accent: accent, green: green, purple: purple,
                        isActive: dns.activeProfileID == profile.id && dns.isEnabled,
                        isActivating: activatingID == profile.id
                    ) {
                        Task { await activate(profile) }
                    } onBottom: {
                        if let vid = profile.videoURL, let url = URL(string: vid) {
                            videoURL = url
                        } else if let url = URL(string: profile.downloadURL) {
                            safariURL = url
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func activate(_ profile: PatchHubService.DNSProfile) async {
        guard activatingID == nil else { return }
        activatingID = profile.id
        defer { activatingID = nil }

        if let doh = profile.dohURL {
            let ok = await dns.activate(profileID: profile.id, dohURL: doh)
            if ok {
                showToast("✓ Đã bật DNS: \(profile.name)")
            } else {
                // Fallback: download .mobileconfig via Safari
                if let url = URL(string: profile.downloadURL) { safariURL = url }
                showToast("Cần cài profile để kích hoạt DNS")
            }
        } else {
            if let url = URL(string: profile.downloadURL) { safariURL = url }
        }
    }

    private func deactivate() async {
        let ok = await dns.deactivate()
        showToast(ok ? "DNS đã tắt, dùng DNS mặc định" : "Không thể tắt DNS")
    }

    private func showToast(_ msg: String) {
        withAnimation(.spring(response: 0.3)) { toastMsg = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut) { toastMsg = nil }
        }
    }
}

// MARK: - Profile Card

private struct DNSProfileCard: View {
    let profile: PatchHubService.DNSProfile
    let accent: Color; let green: Color; let purple: Color
    let isActive: Bool
    let isActivating: Bool
    let onActivate: () -> Void
    let onBottom: () -> Void

    private var hasVideo: Bool { profile.videoURL != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [accent.opacity(0.18), green.opacity(0.10)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder((isActive ? green : accent).opacity(0.30), lineWidth: 1))
                    NextDNSShieldIcon(size: 26, isActive: isActive)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    if !profile.description.isEmpty {
                        Text(profile.description)
                            .font(.system(size: 11)).foregroundStyle(Color(red: 0.50, green: 0.58, blue: 0.75)).lineLimit(2)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(isActive ? green : Color.white.opacity(0.25)).frame(width: 5, height: 5)
                        Text(isActive ? "Đang dùng · DNS-over-HTTPS" : "DNS-over-HTTPS · Sẵn sàng")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(isActive ? green.opacity(0.9) : Color(red: 0.50, green: 0.58, blue: 0.75))
                    }
                }

                Spacer(minLength: 0)

                // Download button (replaces old "Dùng")
                Button { onActivate() } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isActive
                                ? LinearGradient(colors: [green.opacity(0.22), green.opacity(0.10)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [accent.opacity(0.22), green.opacity(0.14)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 56, height: 40)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder((isActive ? green : accent).opacity(0.35), lineWidth: 1))
                        if isActivating {
                            ProgressView().tint(accent).scaleEffect(0.75)
                        } else if isActive {
                            VStack(spacing: 1) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14)).foregroundStyle(green)
                                Text("Đang dùng").font(.system(size: 8, weight: .bold)).foregroundStyle(green)
                            }
                        } else {
                            VStack(spacing: 1) {
                                Image(systemName: "arrow.down.to.line")
                                    .font(.system(size: 14)).foregroundStyle(accent)
                                Text("Tải").font(.system(size: 9, weight: .bold)).foregroundStyle(accent)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isActivating || isActive)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            // Bottom row: video guide OR download fallback
            Button { onBottom() } label: {
                HStack(spacing: 6) {
                    Image(systemName: hasVideo ? "play.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(hasVideo ? Color(red: 0.65, green: 0.45, blue: 1.0) : Color(red: 0.45, green: 0.55, blue: 0.75))
                    Text(hasVideo ? "Xem hướng dẫn dùng dns ngay" : "Tải file .mobileconfig (cài thủ công)")
                        .font(.system(size: 11))
                        .foregroundStyle(hasVideo ? Color(red: 0.65, green: 0.45, blue: 1.0) : Color(red: 0.45, green: 0.55, blue: 0.75))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))
                .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .top)
            }.buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: isActive
                            ? [green.opacity(0.45), green.opacity(0.15)]
                            : [accent.opacity(0.30), green.opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isActive ? 1.5 : 1))
        )
        .shadow(color: isActive ? green.opacity(0.15) : .clear, radius: 10)
    }
}

// MARK: - DNS Notice Sheet

private struct DNSNoticeSheet: View {
    let text: String
    let accent: Color
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
                            Text("Next DNS")
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
                        Button { dismiss() } label: {
                            Text("Đã hiểu")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    LinearGradient(colors: [accent, Color(red: 0.10, green: 0.85, blue: 0.55).opacity(0.85)],
                                                   startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }.buttonStyle(.plain)
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - DNS Video Player

private struct DNSVideoPlayerView: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let vc = AVPlayerViewController()
        vc.player = player
        vc.delegate = context.coordinator
        player.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {}
        func playerViewControllerWillBeginDismissalTransition(_ playerViewController: AVPlayerViewController) {
            playerViewController.player?.pause()
            onDismiss()
        }
    }
}
