import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TechBackground()
                List {
                    // About
                    Section {
                        infoRow(icon: "info.circle", iconColor: AppTheme.accent,
                                title: "Phiên bản", value: appVersion)
                        infoRow(icon: "iphone", iconColor: AppTheme.green,
                                title: "iOS", value: UIDevice.current.systemVersion)
                    } header: {
                        sectionHeader("Thông tin")
                    }

                    // Nguồn gốc
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
                .scrollContentBackground(.hidden)
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
