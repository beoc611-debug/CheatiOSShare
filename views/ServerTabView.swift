import SwiftUI

struct ServerTabView: View {
    @ObservedObject var store: FreefireESPStore
    let sections: [UIConfigSection]

    var body: some View {
        if sections.isEmpty {
            emptyState
        } else {
            VStack(spacing: 14) {
                ForEach(sections) { section in
                    sectionCard(section)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        let red  = Color(red: 1.00, green: 0.18, blue: 0.38)
        let rose = Color(red: 0.85, green: 0.10, blue: 0.28)
        let dark = Color(red: 0.10, green: 0.04, blue: 0.06)

        return VStack(spacing: 20) {
            Spacer().frame(height: 8)

            // Icon
            ZStack {
                Circle()
                    .fill(red.opacity(0.12))
                    .frame(width: 72, height: 72)
                Circle()
                    .strokeBorder(red.opacity(0.25), lineWidth: 1)
                    .frame(width: 72, height: 72)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(red.opacity(0.75))
            }

            VStack(spacing: 6) {
                Text("Tính năng tạm thời bị khóa")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.90, green: 0.85, blue: 0.87))
                Text("Liên hệ admin hoặc theo dõi nhóm\nđể nhận thông báo khi mở lại.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(red: 0.55, green: 0.48, blue: 0.52))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                // Nút liên hệ admin
                Button {
                    if let url = URL(string: "https://t.me/canhioscrack") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Liên hệ Admin")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [rose, red], startPoint: .leading, endPoint: .trailing)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(red.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: red.opacity(0.30), radius: 10, y: 4)
                }
                .buttonStyle(.plain)

                // Nút tham gia nhóm
                Button {
                    if let url = URL(string: "https://t.me/crackcyipa") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Tham gia nhóm nhận thông báo")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(dark.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(red.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Spacer().frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Section card

    private func sectionCard(_ section: UIConfigSection) -> some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(section.accentColor)
                Text(section.title.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(section.accentColor.opacity(0.85))
                    .kerning(1.0)
                Spacer()
            }
            .padding(.bottom, 12)

            VStack(spacing: 8) {
                ForEach(visibleItems(in: section)) { item in
                    itemRow(item, accent: section.accentColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard()
    }

    // MARK: - Item row

    @ViewBuilder
    private func itemRow(_ item: UIConfigItem, accent: Color) -> some View {
        switch item.type {
        case "toggle":
            toggleRow(item, accent: accent)
        default:
            EmptyView()
        }
    }

    private func toggleRow(_ item: UIConfigItem, accent: Color) -> some View {
        let isOn = store.boolValue(for: item.id)
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(item.accentColor.opacity(isOn ? 0.20 : 0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: item.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(item.accentColor.opacity(isOn ? 1.0 : 0.45))
            }

            Text(item.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isOn ? .white : Color(red: 0.60, green: 0.50, blue: 0.52))
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: Binding(
                get: { store.boolValue(for: item.id) },
                set: { _ in store.toggleById(item.id) }
            ))
            .labelsHidden()
            .tint(item.accentColor)
            .scaleEffect(0.85)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { store.toggleById(item.id) }
    }

    // MARK: - Visibility filter

    private func visibleItems(in section: UIConfigSection) -> [UIConfigItem] {
        section.items.filter { item in
            guard let showIf = item.showIf, !showIf.isEmpty else { return true }
            let parentOn = store.boolValue(for: showIf)
            let expectedVal = item.showIfVal ?? "true"
            return expectedVal == "true" ? parentOn : !parentOn
        }
    }
}
