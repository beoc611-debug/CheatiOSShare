import SwiftUI

@MainActor
final class NextDNSViewModel: ObservableObject {
    @Published var profiles: [PatchHubService.DNSProfile] = []
    @Published var isLoading = false
    @Published var loadError: String? = nil

    func load() async {
        isLoading = true
        loadError = nil
        do {
            profiles = try await PatchHubService.fetchDNSProfiles()
        } catch {
            loadError = "Không tải được danh sách DNS"
        }
        isLoading = false
    }
}

struct NextDNSView: View {
    @StateObject private var vm = NextDNSViewModel()
    @State private var downloadingID: String? = nil
    @State private var showInstallTip = false

    private let accent  = Color(red: 0.20, green: 0.70, blue: 1.00)
    private let green   = Color(red: 0.10, green: 0.85, blue: 0.55)
    private let purple  = Color(red: 0.55, green: 0.20, blue: 1.00)

    var body: some View {
        ZStack {
            Color.clear
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                    content
                        .padding(.horizontal, 14)
                    Spacer(minLength: 40)
                }
            }
            .refreshable { await vm.load() }
        }
        .task { await vm.load() }
        .alert("Cách cài DNS Profile", isPresented: $showInstallTip) {
            Button("Đã hiểu", role: .cancel) {}
        } message: {
            Text("1. Bấm nút ↓ để tải file\n2. Safari mở → bấm \"Cho phép\"\n3. Vào Cài đặt → Đã tải về → Cài đặt profile\n4. Vào Cài đặt → VPN & Quản lý thiết bị → Cài đặt")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: [accent.opacity(0.25), green.opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accent.opacity(0.35), lineWidth: 1))
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [accent, green], startPoint: .top, endPoint: .bottom))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Next DNS")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(LinearGradient(
                        colors: [accent, green], startPoint: .leading, endPoint: .trailing))
                Text("DNS Profile · Chống ban · Bảo mật")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
            }
            Spacer()
            Button {
                showInstallTip = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(accent.opacity(0.7))
            }
            .buttonStyle(.plain)
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
                        .frame(height: 76)
                        .redacted(reason: .placeholder)
                        .overlay(
                            LinearGradient(
                                stops: [.init(color: .clear, location: 0),
                                        .init(color: .white.opacity(0.05), location: 0.5),
                                        .init(color: .clear, location: 1.0)],
                                startPoint: .leading, endPoint: .trailing)
                        )
                }
            }
        } else if let err = vm.loadError {
            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 32))
                    .foregroundStyle(accent.opacity(0.7))
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                    .multilineTextAlignment(.center)
                Button { Task { await vm.load() } } label: {
                    Text("Thử lại")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(accent.opacity(0.12), in: Capsule())
                }
            }
            .padding(.vertical, 48).frame(maxWidth: .infinity)
        } else if vm.profiles.isEmpty {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.10))
                        .frame(width: 72, height: 72)
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(accent.opacity(0.6))
                }
                Text("Chưa có DNS Profile")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Admin chưa thêm profile nào.\nVui lòng quay lại sau.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.80))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 52).frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 10) {
                infoBar
                    .padding(.bottom, 6)
                ForEach(vm.profiles) { profile in
                    DNSProfileCard(profile: profile, accent: accent, green: green, purple: purple,
                                   isDownloading: downloadingID == profile.id) {
                        download(profile)
                    }
                }
            }
        }
    }

    private var infoBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(accent.opacity(0.8))
            Text("Bấm ↓ để tải · Sau đó vào Cài đặt để cài profile")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(red: 0.50, green: 0.62, blue: 0.80))
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(accent.opacity(0.18), lineWidth: 1))
    }

    private func download(_ profile: PatchHubService.DNSProfile) {
        guard let url = URL(string: profile.downloadURL) else { return }
        downloadingID = profile.id
        UIApplication.shared.open(url, options: [:]) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                downloadingID = nil
            }
        }
    }
}

// MARK: - Profile Card

private struct DNSProfileCard: View {
    let profile: PatchHubService.DNSProfile
    let accent: Color
    let green: Color
    let purple: Color
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(
                        colors: [accent.opacity(0.18), green.opacity(0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(accent.opacity(0.30), lineWidth: 1))
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [accent, green], startPoint: .top, endPoint: .bottom))
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !profile.description.isEmpty {
                    Text(profile.description)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(red: 0.50, green: 0.58, blue: 0.75))
                        .lineLimit(2)
                }
                HStack(spacing: 4) {
                    Circle().fill(green).frame(width: 5, height: 5)
                    Text("DNS-over-HTTPS · Sẵn sàng")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(green.opacity(0.85))
                }
            }

            Spacer(minLength: 0)

            // Download button
            Button { onDownload() } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(
                            colors: [accent.opacity(0.22), green.opacity(0.14)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(accent.opacity(0.35), lineWidth: 1))
                    if isDownloading {
                        ProgressView().tint(accent).scaleEffect(0.75)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(LinearGradient(
                                colors: [accent, green], startPoint: .top, endPoint: .bottom))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isDownloading)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [accent.opacity(0.30), green.opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1))
        )
    }
}
