import SwiftUI

// MARK: - Custom toggle (wider, with -/✓ icon)

private struct EspToggle: View {
    let isOn: Bool
    let color: Color
    let onToggle: () -> Void

    var body: some View {
        ZStack {
            Capsule()
                .fill(isOn ? color : Color(white: 0.18))
                .overlay(Capsule()
                    .strokeBorder(isOn ? color.opacity(0.25) : Color.white.opacity(0.10), lineWidth: 1))

            HStack(spacing: 0) {
                if isOn { Spacer(minLength: 0) }
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.20), radius: 2, y: 1)
                    Image(systemName: isOn ? "checkmark" : "minus")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(isOn ? color : Color(white: 0.42))
                }
                .padding(3)
                if !isOn { Spacer(minLength: 0) }
            }
        }
        .frame(width: 56, height: 30)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isOn)
        .onTapGesture { onToggle() }
    }
}

// MARK: - Per-element color picker sheet

private struct ESPColorSheet: View {
    @ObservedObject var store: FreefireESPStore
    @Binding var isPresented: Bool

    private static let elements = ["Line", "Box", "Health", "Name", "Distance", "Count", "Skeleton", "FOV"]

    private var idx: Int { store.selectedEspElement }
    private var elemName: String { idx < Self.elements.count ? Self.elements[idx] : "ESP" }
    private var showThickness: Bool { idx == 0 || idx == 1 || idx == 3 || idx == 6 }
    private var isName: Bool { idx == 3 }
    private var showHealthNote: Bool { idx == 2 }

    private func colorFor(_ i: Int) -> Color {
        switch i {
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

    private var elemColor: Color { colorFor(idx) }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { colorFor(store.selectedEspElement) },
            set: { c in
                switch store.selectedEspElement {
                case 0: store.lineColor     = c
                case 1: store.boxColor      = c
                case 2: store.healthColor   = c
                case 3: store.nameColor     = c
                case 4: store.distColor     = c
                case 5: store.countColor    = c
                case 6: store.skeletonColor = c
                default: store.fovColor     = c
                }
                store.flushStatePublic()
            }
        )
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.10).ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(elemColor.opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(elemColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Màu \(elemName)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Tuỳ chỉnh màu & độ dày cho \(elemName)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(elemColor.opacity(0.12))
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(elemColor.opacity(0.45), lineWidth: 1.5)
                    Text(elemName)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(elemColor)
                        .shadow(color: elemColor.opacity(0.6), radius: 10)
                }
                .frame(height: 68)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(elemColor)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                        ColorPicker("Màu \(elemName)", selection: colorBinding, supportsOpacity: false)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.80))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if showHealthNote {
                        Divider().opacity(0.12)
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle").font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                            Text("Health bar width tự theo Box")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    if showThickness {
                        Divider().opacity(0.12)
                        thicknessSection
                    }
                }
                .background(Color(red: 0.10, green: 0.11, blue: 0.16))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private var thicknessSection: some View {
        let thickBinding = Binding<Double>(
            get: {
                if store.selectedEspElement == 0 { return Double(store.lineThicknessRaw) }
                if store.selectedEspElement == 3 { return Double(store.nameThicknessRaw) }
                if store.selectedEspElement == 6 { return Double(store.skelThicknessRaw) }
                return Double(store.boxThicknessRaw)
            },
            set: { v in
                let raw = Int32(v)
                if store.selectedEspElement == 0 { store.lineThicknessRaw = raw }
                else if store.selectedEspElement == 3 { store.nameThicknessRaw = raw }
                else if store.selectedEspElement == 6 { store.skelThicknessRaw = raw }
                else { store.boxThicknessRaw = raw }
                store.flushStatePublic()
            }
        )
        let rawVal: Int32 = idx == 0 ? store.lineThicknessRaw
            : (idx == 3 ? store.nameThicknessRaw
            : (idx == 6 ? store.skelThicknessRaw : store.boxThicknessRaw))
        let displayVal = isName
            ? String(format: "%.1fx", 1.0 + Double(rawVal) * 0.02)
            : String(format: "%.1f px", 0.5 + Double(rawVal) * 0.2)

        return VStack(spacing: 4) {
            HStack(spacing: 12) {
                Image(systemName: isName ? "textformat.size" : "lineweight")
                    .font(.system(size: 14))
                    .foregroundStyle(elemColor)
                Text(isName ? "Name size" : "\(elemName) thickness")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                Spacer()
                Text(displayVal)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(elemColor)
            }
            .padding(.top, 12)
            Slider(value: thickBinding, in: 1...97, step: 1)
                .tint(elemColor)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Main view

struct ServerTabView: View {
    @ObservedObject var store: FreefireESPStore
    let sections: [UIConfigSection]
    @State private var showColorPicker = false

    private static let espElements = ["Line", "Box", "Health", "Name", "Distance", "Count", "Skeleton", "FOV"]
    private static let espChipLabels = ["Line", "Box", "Máu", "Tên", "Cự Ly", "Count", "Skel", "FOV"]

    var body: some View {
        if sections.isEmpty {
            emptyState
        } else {
            VStack(spacing: 14) {
                ForEach(sections) { section in
                    sectionCard(section)
                }
            }
            .padding(.bottom, 16)
            .sheet(isPresented: $showColorPicker) {
                ESPColorSheet(store: store, isPresented: $showColorPicker)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        let red  = Color(red: 1.00, green: 0.18, blue: 0.38)
        let rose = Color(red: 0.85, green: 0.10, blue: 0.28)
        let dark = Color(red: 0.10, green: 0.04, blue: 0.06)

        return VStack(spacing: 20) {
            Spacer().frame(height: 8)
            ZStack {
                Circle().fill(red.opacity(0.12)).frame(width: 72, height: 72)
                Circle().strokeBorder(red.opacity(0.25), lineWidth: 1).frame(width: 72, height: 72)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(red.opacity(0.75))
            }
            VStack(spacing: 6) {
                Text("Tính năng tạm thời bị khóa")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.90, green: 0.85, blue: 0.87))
                Text("Liên hệ admin hoặc theo dõi nhóm\nđể nhận thông báo khi mở lại.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.55, green: 0.48, blue: 0.52))
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                Button {
                    if let url = URL(string: "https://t.me/canhioscrack") { UIApplication.shared.open(url) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane.fill").font(.system(size: 14, weight: .bold))
                        Text("Liên hệ Admin").font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [rose, red], startPoint: .leading, endPoint: .trailing)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(red.opacity(0.45), lineWidth: 1))
                    .shadow(color: red.opacity(0.30), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                Button {
                    if let url = URL(string: "https://t.me/crackcyipa") { UIApplication.shared.open(url) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill").font(.system(size: 14, weight: .bold))
                        Text("Tham gia nhóm nhận thông báo").font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(dark.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(red.opacity(0.35), lineWidth: 1))
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
        let accent  = section.accentColor
        let isESP   = section.title.uppercased() == "ESP"
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent.opacity(0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: section.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accent)
                }
                Text(sectionDisplayTitle(section))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .kerning15(0.5)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 10)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)

            ForEach(Array(visible.enumerated()), id: \.element.id) { idx, item in
                itemRow(item, accent: item.accentColor, isESPSection: isESP)
                    .transition(.opacity)
                if idx < visible.count - 1 {
                    rowDivider
                }
            }

            Spacer(minLength: 8)
        }
        .background(AppTheme.techCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(accent.opacity(0.18), lineWidth: 1))
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.horizontal, 14)
    }

    // MARK: - Item dispatcher

    @ViewBuilder
    private func itemRow(_ item: UIConfigItem, accent: Color, isESPSection: Bool = false) -> some View {
        switch item.type {
        case "toggle":   toggleRow(item, accent: accent, isESPSection: isESPSection)
        case "slider":   sliderRow(item, accent: accent)
        case "segment":  segmentRow(item, accent: accent)
        case "colorPicker": colorPickerRow(item, accent: accent)
        default: EmptyView()
        }
    }

    // MARK: - ESP helpers

    private func sectionDisplayTitle(_ section: UIConfigSection) -> String {
        let t = section.title.uppercased()
        if t == "ESP"  { return "ESP / Định vị" }
        if t == "AIM"  { return "AIM / Ghim tâm" }
        if t == "MISC" { return "MISC" }
        return t
    }

    private func espElementIndex(for item: UIConfigItem) -> Int? {
        let id    = item.id.lowercased()
        let label = item.label.lowercased()
        if id.contains("line")   || label.contains("tracer") || label.contains("line")   { return 0 }
        if id.contains("box")    || label.contains("box")    || label.contains("khung")  { return 1 }
        if id.contains("health") || label.contains("health") || label.contains("máu")    { return 2 }
        if id.contains("name")   || label.contains("name")   || label.contains("tên")    { return 3 }
        if id.contains("dist")   || label.contains("dist")   || label.contains("khoảng") { return 4 }
        if id.contains("count")  || label.contains("count")                               { return 5 }
        if id.contains("skel")   || label.contains("skel")                                { return 6 }
        if id.contains("fov")    || label.contains("fov")                                 { return 7 }
        return nil
    }

    private func colorForEspElement(_ i: Int) -> Color {
        switch i {
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

    private func subtitleFor(_ item: UIConfigItem) -> String? {
        let id    = item.id.lowercased()
        let label = item.label.lowercased()
        // ESP
        if id.contains("box")    || label.contains("box")    { return "Hộp nhận diện bao quanh đối thủ" }
        if id.contains("line")   || label.contains("tracer") { return "Tia định vị từ đỉnh màn hình xuống địch" }
        if id.contains("health") || label.contains("health") { return "Hiển thị lượng máu đối thủ" }
        if id.contains("name")   || label.contains("name")   { return "Nhận diện nickname của mục tiêu" }
        if id.contains("dist")   || label.contains("dist")   { return "Đo cự ly chính xác theo mét" }
        if id.contains("count")  || label.contains("count")  { return "Đếm số lượng địch trong tầm" }
        if id.contains("skel")   || label.contains("skel")   { return "Hiển thị khung xương đối thủ" }
        if id.contains("fov")    || label.contains("fov")    { return "Vùng quan sát của Aim Assist" }
        // AIM
        if id.contains("silent") || label.contains("silent") { return "Tự động nhắm vào mục tiêu không phát tiếng" }
        if id.contains("recoil") || label.contains("recoil") || label.contains("giật") { return "Triệt tiêu độ giật khi bắn" }
        if id.contains("bypass") || label.contains("bỏ qua") || label.contains("gục")  { return "Bỏ qua đối thủ đã ngã gục" }
        if id.contains("aim_at") || id.contains("aimat") || label.contains("nhắm vào") { return "Chọn bộ phận cơ thể ưu tiên nhắm" }
        if id.contains("speed")  || label.contains("speed")  || label.contains("tốc độ") { return "Tăng tốc độ di chuyển nhân vật" }
        // MISC
        if id.contains("fastmag") || id.contains("reload") || label.contains("reload") { return "Tăng tốc độ nạp đạn" }
        if (id.contains("heal") && !id.contains("health")) || label.contains("hồi máu") { return "Tăng tốc độ hồi phục máu" }
        if id.contains("unlock") || label.contains("unlock") || label.contains("mở khóa") { return "Mở khóa phòng và tính năng đặc biệt" }
        if id.contains("antiban") || label.contains("antiban") || label.contains("bảo vệ") { return "Bảo vệ tài khoản khi sử dụng" }
        if id.contains("aimbot") || label.contains("aimbot") { return "Hỗ trợ ngắm bắn tự động" }
        if id.contains("ghost") || label.contains("ghost") || label.contains("ẩn thân") { return "Ẩn hoàn toàn với kẻ địch — không thể nhìn thấy" }
        return nil
    }

    private func hexString(of color: Color) -> String {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func thicknessDisplay(for i: Int) -> String {
        let isName = i == 3
        switch i {
        case 0:
            return String(format: "%.1f px", 0.5 + Double(store.lineThicknessRaw) * 0.2)
        case 1:
            return String(format: "%.1f px", 0.5 + Double(store.boxThicknessRaw) * 0.2)
        case 3:
            return String(format: "%.1fx", 1.0 + Double(store.nameThicknessRaw) * 0.02)
        case 6:
            return String(format: "%.1f px", 0.5 + Double(store.skelThicknessRaw) * 0.2)
        default:
            return isName ? "1.0x" : "1.0 px"
        }
    }

    // Legacy ColorPicker binding (used by colorPickerRow)
    private func espCurrentColorBinding() -> Binding<Color> {
        Binding(
            get: { colorForEspElement(store.selectedEspElement) },
            set: { c in
                switch store.selectedEspElement {
                case 0: store.lineColor     = c
                case 1: store.boxColor      = c
                case 2: store.healthColor   = c
                case 3: store.nameColor     = c
                case 4: store.distColor     = c
                case 5: store.countColor    = c
                case 6: store.skeletonColor = c
                default: store.fovColor     = c
                }
                store.flushStatePublic()
            }
        )
    }

    // MARK: - Toggle row (icon badge + subtitle)

    private func toggleRow(_ item: UIConfigItem, accent: Color, isESPSection: Bool = false) -> some View {
        let isOn    = store.boolValue(for: item.id)
        let color   = item.accentColor
        let elemIdx = isESPSection ? espElementIndex(for: item) : nil
        let sub     = subtitleFor(item)

        return HStack(spacing: 13) {
            // Icon with optional color-dot badge (ESP section only)
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isOn ? color.opacity(0.25) : Color.white.opacity(0.07))
                        .frame(width: 46, height: 46)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(isOn ? color.opacity(0.40) : Color.white.opacity(0.10), lineWidth: 1)
                        )
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isOn ? color : Color(white: 0.35))
                        .scaleEffect(isOn ? 1.05 : 1.0)
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isOn)

                if let ei = elemIdx {
                    let ec = colorForEspElement(ei)
                    Button {
                        store.selectedEspElement = ei
                        showColorPicker = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.05, green: 0.06, blue: 0.10))
                                .frame(width: 17, height: 17)
                            Circle()
                                .fill(ec)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -5)
                }
            }

            // Label + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(item.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isOn ? .white : Color(white: 0.58))
                    .animation(.easeInOut(duration: 0.15), value: isOn)
                if let s = sub {
                    Text(s)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.38))
                        .lineLimit(1)
                }
            }

            Spacer()

            EspToggle(isOn: store.boolValue(for: item.id), color: color) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    store.toggleById(item.id)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - Slider row

    private func sliderRow(_ item: UIConfigItem, accent: Color) -> some View {
        let color   = item.accentColor
        let minVal  = item.min  ?? 0
        let maxVal  = item.max  ?? 100
        let stepVal = item.step ?? 1
        let unit    = item.unit ?? ""

        return VStack(spacing: 2) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(item.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                Spacer()
                Text("\(Int(store.doubleValue(for: item.id)))\(unit)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.vertical, 10)
            Slider(
                value: Binding(
                    get: { store.doubleValue(for: item.id) },
                    set: { store.setDouble(for: item.id, $0) }
                ),
                in: minVal...maxVal,
                step: stepVal
            )
            .tint(color)
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Segment row

    private func segmentRow(_ item: UIConfigItem, accent: Color) -> some View {
        let color    = item.accentColor
        let options  = item.options ?? []
        let selected = Int(store.doubleValue(for: item.id))
        let segBar = HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                let isActive = i == selected
                Button { store.setDouble(for: item.id, Double(i)) } label: {
                    Text(options[i])
                        .font(.system(size: 12, weight: isActive ? .bold : .medium))
                        .foregroundStyle(isActive ? .white : Color(red: 0.45, green: 0.55, blue: 0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
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

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                    if let sub = subtitleFor(item) {
                        Text(sub)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(white: 0.38))
                    }
                }
                Spacer()
            }
            segBar
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Color picker row (redesigned — BẢNG MÀU style)

    @ViewBuilder
    private func colorPickerRow(_ item: UIConfigItem, accent: Color) -> some View {
        let elemIdx   = store.selectedEspElement
        let elemColor = colorForEspElement(elemIdx)
        let elemName  = elemIdx < Self.espElements.count ? Self.espElements[elemIdx] : "ESP"
        let hex       = hexString(of: elemColor)
        let thick     = thicknessDisplay(for: elemIdx)
        let hasThick  = elemIdx == 0 || elemIdx == 1 || elemIdx == 3 || elemIdx == 6

        VStack(spacing: 0) {
            // Caption
            HStack {
                Text("CHỌN LOẠI ESP ĐỂ THIẾT LẬP:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.32))
                    .kerning15(0.5)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Filter chips (scrollable)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(Self.espChipLabels.enumerated()), id: \.offset) { i, chipName in
                        let isSelected = store.selectedEspElement == i
                        let chipColor  = colorForEspElement(i)
                        Button { store.selectedEspElement = i } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(chipColor)
                                    .frame(width: 7, height: 7)
                                Text(chipName)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected ? .white : Color.white.opacity(0.48))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? chipColor.opacity(0.25) : Color.white.opacity(0.07))
                            .clipShape(Capsule())
                            .overlay(Capsule()
                                .strokeBorder(isSelected ? chipColor.opacity(0.65) : Color.clear, lineWidth: 1))
                            .animation(.easeInOut(duration: 0.12), value: isSelected)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 12)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)

            // Color info row
            HStack(spacing: 12) {
                // Color square
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(elemColor)
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    Text(elemName + "  " + hex)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(hasThick ? "Dày \(thick)" : "—")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.38))
                }

                Spacer()

                // BẢNG MÀU button → opens ESPColorSheet
                Button {
                    showColorPicker = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("BẢNG MÀU")
                            .font(.system(size: 11, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(elemColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(elemColor.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(elemColor.opacity(0.42), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Health note
            if elemIdx == 2 {
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                    Text("Health bar width tự theo Box")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            // Inline thickness slider
            if hasThick {
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
                inlineThicknessSlider(elemIdx: elemIdx, elemColor: elemColor)
            }
        }
    }

    @ViewBuilder
    private func inlineThicknessSlider(elemIdx: Int, elemColor: Color) -> some View {
        let isName = elemIdx == 3
        let elemName = elemIdx < Self.espElements.count ? Self.espElements[elemIdx] : ""
        let thickBinding = Binding<Double>(
            get: {
                if store.selectedEspElement == 0 { return Double(store.lineThicknessRaw) }
                if store.selectedEspElement == 3 { return Double(store.nameThicknessRaw) }
                if store.selectedEspElement == 6 { return Double(store.skelThicknessRaw) }
                return Double(store.boxThicknessRaw)
            },
            set: { v in
                let raw = Int32(v)
                if store.selectedEspElement == 0 { store.lineThicknessRaw = raw }
                else if store.selectedEspElement == 3 { store.nameThicknessRaw = raw }
                else if store.selectedEspElement == 6 { store.skelThicknessRaw = raw }
                else { store.boxThicknessRaw = raw }
                store.flushStatePublic()
            }
        )
        let rawVal: Int32 = elemIdx == 0 ? store.lineThicknessRaw
            : (elemIdx == 3 ? store.nameThicknessRaw
            : (elemIdx == 6 ? store.skelThicknessRaw : store.boxThicknessRaw))
        let displayVal = isName
            ? String(format: "%.1fx", 1.0 + Double(rawVal) * 0.02)
            : String(format: "%.1f px", 0.5 + Double(rawVal) * 0.2)

        VStack(spacing: 2) {
            HStack(spacing: 10) {
                Image(systemName: isName ? "textformat.size" : "lineweight")
                    .font(.system(size: 13))
                    .foregroundStyle(elemColor)
                Text(isName ? "Name size" : "\(elemName) thickness")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                Spacer()
                Text(displayVal)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(elemColor)
            }
            .padding(.top, 10)
            Slider(value: thickBinding, in: 1...97, step: 1)
                .tint(elemColor)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Visibility filter

    private func visibleItems(in section: UIConfigSection) -> [UIConfigItem] {
        section.items.filter { item in
            if let showIf = item.showIf, !showIf.isEmpty {
                let parentOn    = store.boolValue(for: showIf)
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
