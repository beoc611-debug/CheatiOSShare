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
        let visible = visibleItems(in: section)
        return VStack(spacing: 0) {
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
            .padding(.bottom, 10)

            ForEach(visible.indices, id: \.self) { idx in
                itemRow(visible[idx], accent: section.accentColor)
                if idx < visible.count - 1 {
                    rowDivider
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard()
    }

    // MARK: - Row divider

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.horizontal, 4)
    }

    // MARK: - Item row

    @ViewBuilder
    private func itemRow(_ item: UIConfigItem, accent: Color) -> some View {
        switch item.type {
        case "toggle":
            toggleRow(item, accent: accent)
        case "slider":
            sliderRow(item, accent: accent)
        case "segment":
            segmentRow(item, accent: accent)
        default:
            EmptyView()
        }
    }

    private func toggleRow(_ item: UIConfigItem, accent: Color) -> some View {
        let isOn = store.boolValue(for: item.id)
        let color = item.accentColor
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(isOn ? color.opacity(0.22) : Color.white.opacity(0.07))
                    .frame(width: 38, height: 38)
                    .animation(.easeInOut(duration: 0.10), value: isOn)
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOn ? color : Color(red: 0.40, green: 0.48, blue: 0.65))
                    .animation(.easeInOut(duration: 0.10), value: isOn)
            }
            Text(item.label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOn ? .white : Color(red: 0.52, green: 0.60, blue: 0.78))
                .animation(.easeInOut(duration: 0.10), value: isOn)
            Spacer()
            HStack(spacing: 0) {
                Button { if isOn { store.toggleById(item.id) } } label: {
                    Text("Tắt")
                        .font(.system(size: 12, weight: !isOn ? .bold : .medium))
                        .foregroundStyle(!isOn ? .white : Color(red: 0.45, green: 0.55, blue: 0.75))
                        .frame(width: 40, height: 28)
                        .background(!isOn
                            ? AnyView(Capsule().fill(Color(red: 0.30, green: 0.32, blue: 0.45)))
                            : AnyView(Color.clear))
                        .animation(.easeInOut(duration: 0.10), value: isOn)
                }
                .buttonStyle(.plain)
                Button { if !isOn { store.toggleById(item.id) } } label: {
                    Text("Bật")
                        .font(.system(size: 12, weight: isOn ? .bold : .medium))
                        .foregroundStyle(isOn ? .white : Color(red: 0.45, green: 0.55, blue: 0.75))
                        .frame(width: 40, height: 28)
                        .background(isOn
                            ? AnyView(Capsule().fill(color.opacity(0.85)))
                            : AnyView(Color.clear))
                        .animation(.easeInOut(duration: 0.10), value: isOn)
                }
                .buttonStyle(.plain)
            }
            .padding(2)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
        }
        .padding(.vertical, 11)
    }

    private func sliderRow(_ item: UIConfigItem, accent: Color) -> some View {
        let minVal = item.min ?? 0
        let maxVal = item.max ?? 100
        let stepVal = item.step ?? 1
        let unit = item.unit ?? ""
        let color = item.accentColor

        return VStack(spacing: 2) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(color.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(item.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                Spacer()
                Text("\(Int(store.doubleValue(for: item.id)))\(unit)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 48, alignment: .trailing)
            }
            .padding(.vertical, 8)
            Slider(
                value: Binding(
                    get: { store.doubleValue(for: item.id) },
                    set: { store.setDouble(for: item.id, $0) }
                ),
                in: minVal...maxVal,
                step: stepVal
            )
            .tint(color)
            .padding(.bottom, 8)
        }
    }

    private func segmentRow(_ item: UIConfigItem, accent: Color) -> some View {
        let color = item.accentColor
        let options = item.options ?? []
        let selected = Int(store.doubleValue(for: item.id))
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(item.label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
            Spacer()
            HStack(spacing: 0) {
                ForEach(options.indices, id: \.self) { i in
                    let isActive = i == selected
                    Button { store.setDouble(for: item.id, Double(i)) } label: {
                        Text(options[i])
                            .font(.system(size: 11, weight: isActive ? .bold : .medium))
                            .foregroundStyle(isActive ? .white : Color(red: 0.45, green: 0.55, blue: 0.75))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(isActive
                                ? AnyView(Capsule().fill(color.opacity(0.35)).overlay(Capsule().strokeBorder(color.opacity(0.6), lineWidth: 1)))
                                : AnyView(Color.clear))
                            .animation(.easeInOut(duration: 0.10), value: isActive)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
        }
        .padding(.vertical, 11)
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
