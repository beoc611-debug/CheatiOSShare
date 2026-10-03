import SwiftUI

struct ServerTabView: View {
    @ObservedObject var store: FreefireESPStore
    let sections: [UIConfigSection]

    private static let espElements = ["Line", "Box", "Health", "Name", "Distance", "Count", "Skeleton", "FOV"]

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
        case "colorPicker":
            colorPickerRow(item, accent: accent)
        default:
            EmptyView()
        }
    }

    // MARK: - ESP color helpers

    private func espCurrentColor() -> Color {
        switch store.selectedEspElement {
        case 0: return store.lineColor
        case 1: return store.boxColor
        case 2: return store.healthColor
        case 3: return store.nameColor
        case 4: return store.distColor
        case 5: return store.countColor
        case 6: return store.skeletonColor
        default: return store.fovColor
        }
    }

    private func espCurrentColorBinding() -> Binding<Color> {
        Binding(
            get: { self.espCurrentColor() },
            set: { newColor in
                switch self.store.selectedEspElement {
                case 0: self.store.lineColor     = newColor
                case 1: self.store.boxColor      = newColor
                case 2: self.store.healthColor   = newColor
                case 3: self.store.nameColor     = newColor
                case 4: self.store.distColor     = newColor
                case 5: self.store.countColor    = newColor
                case 6: self.store.skeletonColor = newColor
                default: self.store.fovColor     = newColor
                }
                self.store.flushStatePublic()
            }
        )
    }

    @ViewBuilder
    private func colorPickerRow(_ item: UIConfigItem, accent: Color) -> some View {
        let color = item.accentColor
        VStack(spacing: 0) {
            // Element selector
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(color.opacity(0.18)).frame(width: 38, height: 38)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text("Element")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                Spacer()
                Circle()
                    .fill(espCurrentColor())
                    .frame(width: 20, height: 20)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                HStack(spacing: 0) {
                    Button {
                        store.selectedEspElement = (store.selectedEspElement + Self.espElements.count - 1) % Self.espElements.count
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color)
                            .frame(width: 28, height: 30)
                    }.buttonStyle(.plain)
                    Text(Self.espElements[store.selectedEspElement])
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 54)
                    Button {
                        store.selectedEspElement = (store.selectedEspElement + 1) % Self.espElements.count
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color)
                            .frame(width: 28, height: 30)
                    }.buttonStyle(.plain)
                }
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
            }
            .padding(.vertical, 11)

            rowDivider

            // Color wheel picker
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(espCurrentColor().opacity(0.3)).frame(width: 38, height: 38)
                    Image(systemName: "circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(espCurrentColor())
                }
                ColorPicker(
                    Self.espElements[store.selectedEspElement],
                    selection: espCurrentColorBinding(),
                    supportsOpacity: false
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
            }
            .padding(.vertical, 8)

            // Health info note (no separate thickness)
            if store.selectedEspElement == 2 {
                rowDivider
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.white.opacity(0.07)).frame(width: 38, height: 38)
                        Image(systemName: "info.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                    }
                    Text("Health bar width tự theo Box")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            // Thickness slider (Line=0, Box=1, Name=3, Skeleton=6)
            if store.selectedEspElement == 0 || store.selectedEspElement == 1
                || store.selectedEspElement == 3 || store.selectedEspElement == 6 {
                rowDivider
                let isName = store.selectedEspElement == 3
                let elemName = Self.espElements[store.selectedEspElement]
                let thickBinding = Binding<Double>(
                    get: {
                        if self.store.selectedEspElement == 0 { return Double(self.store.lineThicknessRaw) }
                        if self.store.selectedEspElement == 3 { return Double(self.store.nameThicknessRaw) }
                        if self.store.selectedEspElement == 6 { return Double(self.store.skelThicknessRaw) }
                        return Double(self.store.boxThicknessRaw)
                    },
                    set: { v in
                        let raw = Int32(v)
                        if self.store.selectedEspElement == 0 { self.store.lineThicknessRaw = raw }
                        else if self.store.selectedEspElement == 3 { self.store.nameThicknessRaw = raw }
                        else if self.store.selectedEspElement == 6 { self.store.skelThicknessRaw = raw }
                        else { self.store.boxThicknessRaw = raw }
                        self.store.flushStatePublic()
                    }
                )
                let rawVal: Int32 = store.selectedEspElement == 0 ? store.lineThicknessRaw
                    : (store.selectedEspElement == 3 ? store.nameThicknessRaw
                    : (store.selectedEspElement == 6 ? store.skelThicknessRaw : store.boxThicknessRaw))
                let displayVal = isName
                    ? String(format: "%.1fx", 1.0 + Double(rawVal) * 0.02)
                    : String(format: "%.1f px", 0.5 + Double(rawVal) * 0.2)

                VStack(spacing: 2) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(color.opacity(0.18)).frame(width: 38, height: 38)
                            Image(systemName: isName ? "textformat.size" : "lineweight")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(color)
                        }
                        Text(isName ? "Name size" : "\(elemName) thickness")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                        Spacer()
                        Text(displayVal)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(color)
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    Slider(value: thickBinding, in: 1...97, step: 1)
                        .tint(color)
                        .padding(.bottom, 8)
                }
            }
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
            if let showIf = item.showIf, !showIf.isEmpty {
                let parentOn = store.boolValue(for: showIf)
                let expectedVal = item.showIfVal ?? "true"
                if !(expectedVal == "true" ? parentOn : !parentOn) { return false }
            }
            if let eq = item.showIfEquals {
                let currentVal = Int(store.doubleValue(for: eq.id))
                if currentVal != eq.value { return false }
            }
            return true
        }
    }
}
