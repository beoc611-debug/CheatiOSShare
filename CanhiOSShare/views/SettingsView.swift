import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @Environment(\.dismiss) private var dismiss
    @State private var showLicenseInfo = false

    var body: some View {
        NavigationView {
            ZStack {
                TechBackground()
                List {
                    // License key section
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(AppTheme.neonPurple.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.neonPurple)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mã Key")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(licenseGate.maskedKeyCode.isEmpty ? "Chưa kích hoạt" : licenseGate.maskedKeyCode)
                                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            Spacer()
                            Button {
                                showLicenseInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(AppTheme.techGlow)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(AppTheme.card)

                        Button(role: .destructive) {
                            licenseGate.changeKey()
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(AppTheme.red.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "key.slash")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.red)
                                }
                                Text("Đổi Key")
                                    .foregroundStyle(AppTheme.red)
                            }
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(AppTheme.card)
                    } header: {
                        sectionHeader("Bản quyền")
                    }

                    // About
                    Section {
                        infoRow(icon: "info.circle", iconColor: AppTheme.accent,
                                title: "Phiên bản", value: appVersion)
                        infoRow(icon: "iphone", iconColor: AppTheme.green,
                                title: "iOS", value: UIDevice.current.systemVersion)
                    } header: {
                        sectionHeader("Thông tin")
                    }

                    // Credits
                    Section {
                        linkRow(icon: "person.fill", iconColor: AppTheme.purple,
                                title: "Tác giả", value: "HỒ XUÂN CẢNH (Cảnh iOS Crack)")
                        linkRow(icon: "doc.text", iconColor: AppTheme.accent,
                                title: "Dựa trên", value: "FilzaSlop (0xjohnnydev)")
                        linkRow(icon: "doc.text", iconColor: Color(red: 0.9, green: 0.5, blue: 0.2),
                                title: "Exploit lõi", value: "kexploit_opa334 (opa334)")
                    } header: {
                        sectionHeader("Mã nguồn & Bản quyền")
                    }

                    // Disclaimer
                    Section {
                        Text("Chỉ dùng cho mục đích cá nhân và nghiên cứu. Người dùng tự chịu trách nhiệm về các hành động thực hiện trên thiết bị của mình.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .listRowBackground(AppTheme.card)
                    } header: {
                        sectionHeader("Tuyên bố miễn trách")
                    }
                }
                .listStyle(.insetGrouped)
                .hideScrollBackground()
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLicenseInfo) {
            LicenseInfoSheetView()
                .environmentObject(licenseGate)
        }
    }

    private func infoRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.textSecondary)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
        .listRowBackground(AppTheme.card)
    }

    private func linkRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(AppTheme.card)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .textCase(nil)
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
