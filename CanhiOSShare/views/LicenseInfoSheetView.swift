import SwiftUI

struct LicenseInfoSheetView: View {
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var fullKey: String {
        licenseGate.storedKeyCode ?? ""
    }

    private var expiresAt: Date? { licenseGate.expiresAt }

    private var remainingText: String {
        licenseGate.remainingTimeText(language: language)
    }

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.04, blue: 0.11)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.neonPurple.opacity(0.35), AppTheme.techGlow.opacity(0.20)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Circle().strokeBorder(AppTheme.neonPurple.opacity(0.55), lineWidth: 1)
                                )
                                .shadow(color: AppTheme.neonPurple.opacity(0.4), radius: 16)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.neonPurple, AppTheme.techGlow],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                        }
                        Text("Thông tin Key")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Chi tiết bản quyền của bạn")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.82))
                    }
                    .padding(.top, 28)

                    // Key code card
                    infoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            label("Mã Key")
                            Text(fullKey.isEmpty ? "—" : fullKey)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .textSelection(.enabled)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(red: 0.05, green: 0.08, blue: 0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    // Time info card
                    infoCard {
                        VStack(alignment: .leading, spacing: 14) {
                            label("Thời hạn")
                            HStack(spacing: 14) {
                                timeRow(
                                    icon: "clock.fill",
                                    color: Color(red: 0.10, green: 0.88, blue: 0.52),
                                    title: "Còn lại",
                                    value: remainingText.isEmpty ? "—" : remainingText
                                )
                            }
                            if let exp = expiresAt {
                                Divider().background(AppTheme.techGlow.opacity(0.15))
                                timeRow(
                                    icon: "calendar",
                                    color: AppTheme.techGlow,
                                    title: "Hết hạn lúc",
                                    value: Self.dateFormatter.string(from: exp)
                                )
                            }
                        }
                    }

                    // Devices card
                    infoCard {
                        VStack(alignment: .leading, spacing: 14) {
                            label("Thiết bị đã kích hoạt")
                            if licenseGate.licenseDevices.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "iphone.slash")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.82))
                                    Text("Chưa có thiết bị")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.82))
                                }
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(Array(licenseGate.licenseDevices.enumerated()), id: \.offset) { idx, device in
                                        deviceRow(index: idx + 1, device: device)
                                        if idx < licenseGate.licenseDevices.count - 1 {
                                            Divider().background(AppTheme.techGlow.opacity(0.12))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Đóng")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.neonPurple, AppTheme.techGlow],
                                    startPoint: .leading, endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                            .shadow(color: AppTheme.neonPurple.opacity(0.55), radius: 14, y: 4)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.06, green: 0.09, blue: 0.20).opacity(0.90))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.techGlow.opacity(0.30), AppTheme.neonPurple.opacity(0.22)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .kerning(1.2)
            .foregroundStyle(Color(red: 0.42, green: 0.55, blue: 0.78))
    }

    @ViewBuilder
    private func timeRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.82))
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private func deviceRow(index: Int, device: LicenseDeviceEntry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.techGlow.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "iphone")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.techGlow)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(device.deviceModel ?? "iPhone")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                if let rd = device.redeemedAt {
                    Text("Kích hoạt: \(Self.dateFormatter.string(from: rd))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.82))
                }
            }
            Spacer()
            Text("#\(index)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.neonPurple.opacity(0.8))
        }
    }
}
