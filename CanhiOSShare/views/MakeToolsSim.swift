import SwiftUI

// MARK: - Mô hình cảnh mô phỏng

enum MakeSimKind {
    case figure, gun, holo
}

enum MakeColliderMode {
    case none, normal, off
}

struct MakeSimSpec: Identifiable {
    let key: String
    let value: String
    var highlight = false
    var wide = false
    var id: String { key }
}

struct MakeSimLegend: Identifiable {
    let color: Color
    let text: String
    var id: String { text }
}

struct MakeSimScene {
    var kind: MakeSimKind = .figure
    var accent: Color = .cyan
    var gender: MakeGender = .male
    var chip = "—"
    var note = ""
    var specs: [MakeSimSpec] = []
    var legend: [MakeSimLegend] = []
    var showGender = true

    // Hình người
    var active = true
    var hasZone = false
    var zoneX: CGFloat = 150
    var zoneY: CGFloat = 0
    var zoneR: CGFloat = 20
    var ghostR: CGFloat = 17
    var beam: Double = 0
    var toeLink = false
    var colliders: MakeColliderMode = .none
    var giantRV: CGFloat = 0
    var giantH: CGFloat = 0
    var swap = false
    var showCross = true
    var crossTarget = CGPoint(x: 150, y: 100)
    var crossStart = CGPoint(x: 62, y: 60)
    var wideAim = false

    // Shader súng
    var xray: Color = .black
    var xrayAlpha: Double = 1
    var line: Color = .white
    var lineWidth: CGFloat = 4
    var dim: Color = .black

    // Hologram
    var tint: Color = .cyan
    var rim: Color = .cyan
    var scan: Color = .black
    var tintA: Double = 1
    var rimA: Double = 1
    var scanA: Double = 1
    var xrayOn = true
    var lineOn = false
    var glitchOn = false

    /// Vùng nhìn của khung lớn / ảnh thu nhỏ (toạ độ viewBox 300 × 430)
    var stageBox: CGRect {
        kind == .gun ? CGRect(x: 10, y: 110, width: 280, height: 230) : CGRect(x: 0, y: 14, width: 300, height: 404)
    }
    var thumbBox: CGRect {
        kind == .gun ? CGRect(x: 18, y: 140, width: 270, height: 150) : CGRect(x: 40, y: 16, width: 220, height: 250)
    }
}

// MARK: - Dựng cảnh từ thông số của store (port của hàm build() trong bản HTML)

enum MakeSimBuilder {
    static let cx: CGFloat = 150
    static let base: CGFloat = 15
    static let ant = Color(red: 0.98, green: 0.75, blue: 0.14)
    static let ghostColor = Color(red: 0.58, green: 0.64, blue: 0.72)
    static let colColor = Color(red: 0.38, green: 0.65, blue: 0.98)

    static func yUma(_ x: Double) -> CGFloat { CGFloat(190 + x * 384) }
    static func yCache(_ x: Double) -> CGFloat { CGFloat(95 + (x - 0.005245) * 628) }

    static func zoneName(_ y: CGFloat) -> String {
        if y < 48 { return "Đỉnh đầu" }
        if y < 66 { return "Đầu / Mặt" }
        if y < 84 { return "Cằm" }
        if y < 110 { return "Cổ / Yết hầu" }
        if y < 138 { return "Ngực trên" }
        if y < 188 { return "Ngực / Thân" }
        if y < 232 { return "Bụng" }
        return "Hông"
    }

    static func startOffset(_ y: CGFloat) -> CGPoint {
        let from: CGFloat = y < 150 ? 195 : (y > 205 ? 130 : 195)
        return CGPoint(x: 62, y: from - y)
    }

    static func fmt(_ v: Double, _ d: Int) -> String { String(format: "%.\(d)f", v) }
    static func sgn(_ v: Double, _ d: Int) -> String { (v < 0 ? "−" : "+") + String(format: "%.\(d)f", abs(v)) }

    static func color(_ store: MakeToolsStore, _ id: String, _ d: String) -> Color {
        Color(hex: store.hex(id, d)) ?? .white
    }

    static func build(_ id: String, gender g: MakeGender, store: MakeToolsStore, mini: Bool) -> MakeSimScene {
        guard let preset = MakeToolsCatalog.preset(id) else { return MakeSimScene() }
        var sc = MakeSimScene()
        sc.accent = preset.category.color
        sc.gender = g
        let male = g == .male
        let gname = male ? "nam" : "nữ"
        func spec(_ k: String, _ v: String, hl: Bool = false, wide: Bool = false) {
            sc.specs.append(MakeSimSpec(key: k, value: v, highlight: hl, wide: wide))
        }

        switch id {
        // ---- UMA: bone_Head giả kéo lên/xuống theo position.x ----
        case "1", "2", "5", "6", "7", "8", "9", "10", "11", "12", "13":
            var hips = false
            var hasZone = true
            var x = 0.0
            var s = 1.0
            var act = true
            var dz: CGFloat = 0
            var beam = 0.0
            var toe = false
            var wide = false
            var bytes = ""
            switch id {
            case "1": hips = true; s = 1.5
            case "2":
                x = male ? store.val("mx", -0.3133402) : store.val("fx", -0.23)
                s = store.val("sc", 1.5555556)
                dz = male ? 0 : CGFloat(store.raw("fz", -0.01) * 384)
                bytes = "dựng lại bundle"
            case "5":
                x = store.val("aimToeX", -0.3850825); s = store.val("aimToeScale", 1.5)
                act = store.flag(male ? "aimMale" : "aimFemale"); toe = true; bytes = "46.096 byte, sửa tại chỗ"
            case "6":
                hasZone = false; beam = store.val("antenaHeight", 250)
                act = store.flag(male ? "antenaMale" : "antenaFemale"); bytes = "4 byte"
            case "7":
                x = store.val("bodyPosX", -0.0446)
                s = male ? store.val("bodyMaleScale", 1.555556) : store.val("bodyFemaleScale", 1.5)
                act = store.flag(male ? "bodyMale" : "bodyFemale"); bytes = "44 byte"
            case "8":
                x = store.val("neckPosX", -0.24462); s = store.val("neckScale", 1.5)
                act = store.flag(male ? "neckMale" : "neckFemale"); bytes = "49 byte"
            case "10":
                x = store.val("facePosX", -0.31); s = store.val("faceScale", 1.8)
                act = store.flag(male ? "faceMale" : "faceFemale"); bytes = "44 byte"
            case "11":
                x = store.val("legitPosX", -0.18); s = store.val("legitScale", 1.25)
                act = store.flag(male ? "legitMale" : "legitFemale"); bytes = "44 byte"
            case "9":
                x = store.val("magicPosX", -0.2); s = store.val("magicScale", 3)
                act = store.flag(male ? "magicMale" : "magicFemale"); wide = true; bytes = "44 byte"
            case "12":
                x = store.val("comboPosX", -0.24462); s = store.val("comboScale", 1.5)
                act = store.flag(male ? "comboMale" : "comboFemale"); beam = store.val("comboAntena", 250); bytes = "sửa tại chỗ"
            default: // 13
                x = store.val("custPosX", -0.24462); s = store.val("custScale", 1.5)
                act = store.flag(male ? "custMale" : "custFemale")
                beam = store.flag("custAntena") ? store.val("custAntenaHeight", 250) : 0
                toe = store.flag("custToe"); bytes = "sửa tại chỗ"
            }

            let y: CGFloat = hips ? 250 : (hasZone ? yUma(x) : 0)
            let zx = cx + dz
            let r = hasZone ? base * CGFloat(s) : 0
            sc.active = act
            sc.hasZone = hasZone && act
            sc.zoneX = zx; sc.zoneY = y; sc.zoneR = r
            sc.ghostR = 17
            sc.beam = act ? beam : 0
            sc.toeLink = act && toe && hasZone
            sc.swap = hips && act
            sc.wideAim = wide
            sc.showCross = act && hasZone
            if act && hasZone {
                let tx = wide ? cx + r * 0.78 : zx
                let ty = wide ? y + r * 0.5 : y
                sc.crossTarget = CGPoint(x: tx, y: ty)
                sc.crossStart = startOffset(ty)
                sc.chip = hips ? "Hông (lệch khỏi đầu)" : zoneName(y)
            } else if act {
                sc.chip = "Cột sóng từ bàn tay"
            } else {
                sc.chip = "CHƯA ÁP DỤNG"
                sc.note = "Mesh \(gname) đang tắt trong ô tinh chỉnh — file sẽ không sửa mesh này."
            }

            if id == "1" {
                spec("Thao tác", "Tráo tên + CRC32: bone_Hips ⇄ bone_Neck", wide: true)
                spec("Vùng headshot", "Hông", hl: true); spec("Sửa", "4 byte / mục tiêu"); spec("File", "giữ nguyên dung lượng")
            } else if id == "6" {
                spec("Xương", "bindPoses[4] · " + (male ? "bone_RightHand" : "bone_LeftHand"), wide: true)
                spec("e33", "1.0 → " + fmt(beam, 1), hl: true); spec("Sửa", bytes); spec("File", "46.096 byte")
            } else {
                spec("Xương", "bone_Head ← bone_Left_Weapon", wide: true)
                spec("Cha xương", "bone_Spine1")
                spec("position.x", sgn(x, 4), hl: true)
                spec("Scale", "×" + trimNumber(s), hl: true)
                spec("Vùng aim", zoneName(y), hl: true)
                spec("Sửa", bytes)
                if id == "2" && !male { spec("position.z", sgn(store.raw("fz", -0.01), 3)) }
                if toe { spec("bone_LeftToe", "kéo lên · scale " + fmt(store.val("aimToeScale", 1.5), 1) + (id == "5" ? "" : " (toeDrag)")) }
                if beam > 0 { spec("Antena e33", fmt(beam, 1), hl: true) }
            }
            sc.legend = [MakeSimLegend(color: sc.accent, text: id == "1" ? "Hitbox headshot bị tráo" : "Vùng headshot mới (bone_Head giả)"),
                         MakeSimLegend(color: ghostColor, text: "Hitbox đầu gốc")]
            if beam > 0 { sc.legend.append(MakeSimLegend(color: ant, text: "Cột sóng Antena")) }

        // ---- cache_res: sửa CapsuleCollider ----
        case "14", "15", "16", "18":
            let k: (String, String, String, String, String, String, Double, Double, Double, Double)
            switch id {
            case "14": k = ("hbMale", "hbFemale", "hbMaleCenterX", "hbFemaleCenterX", "hbMaleRadius", "hbFemaleRadius", 0.124686, 0.124096, 0.099059, 0.099154)
            case "15": k = ("dragMale", "dragFemale", "dragMaleCenterX", "dragFemaleCenterX", "dragMaleRadius", "dragFemaleRadius", 0.005245, 0.005775, 0.099059, 0.099154)
            case "16": k = ("neckCacheMale", "neckCacheFemale", "neckCacheMaleCenterX", "neckCacheFemaleCenterX", "neckCacheMaleRadius", "neckCacheFemaleRadius", 0.005245, 0.005775, 0.075, 0.0751)
            default: k = ("chestMale", "chestFemale", "chestMaleCenterX", "chestFemaleCenterX", "chestMaleRadius", "chestFemaleRadius", 0.039245, 0.039245, 0.099059, 0.099154)
            }
            let act = store.flag(male ? k.0 : k.1)
            let cxv = store.val(male ? k.2 : k.3, male ? k.6 : k.7)
            let rad = store.val(male ? k.4 : k.5, male ? k.8 : k.9)
            let y = yCache(cxv)
            let r = CGFloat(rad * 222)
            let off = id == "14" && store.flag("hbZeroOthers")
            sc.active = act
            sc.hasZone = act
            sc.zoneX = cx; sc.zoneY = y; sc.zoneR = r
            sc.ghostR = 22
            sc.colliders = off ? .off : .normal
            sc.showCross = act
            sc.crossTarget = CGPoint(x: cx, y: y)
            sc.crossStart = startOffset(y)
            if act {
                sc.chip = zoneName(y)
            } else {
                sc.chip = "CHƯA ÁP DỤNG"
                sc.note = "Mesh \(gname) đang tắt trong ô tinh chỉnh — file sẽ không sửa mesh này."
            }
            spec("Collider", "CapsuleCollider · bone_Head", wide: true)
            spec("Center.x", sgn(cxv, 6), hl: true); spec("Radius", fmt(rad, 6), hl: true); spec("Vùng aim", zoneName(y), hl: true)
            spec("Collider khác", off ? "34 cái bị triệt tiêu (r = h = 0)" : "35 cái giữ nguyên", hl: off)
            spec("File", "63.056 byte")
            sc.legend = [MakeSimLegend(color: sc.accent, text: "Hitbox đầu (đã dời)"),
                         MakeSimLegend(color: ghostColor, text: "Vị trí đầu gốc"),
                         MakeSimLegend(color: colColor, text: off ? "Collider thân — đã tắt" : "Collider thân — giữ nguyên")]

        case "17":
            let rad = store.val("magicCacheRadius", 0.8)
            let hgt = store.val("magicCacheHeight", 0.8)
            let bd = store.flag("magicCacheBody")
            let hd = store.flag("magicCacheHead")
            sc.giantRV = bd ? CGFloat(Swift.min(96, rad * 115)) : 0
            sc.giantH = CGFloat(hgt * 12)
            sc.colliders = bd ? .none : .normal
            sc.hasZone = true
            sc.zoneX = cx; sc.zoneY = 52
            sc.zoneR = hd ? CGFloat(Swift.min(110, rad * 130)) : 22
            sc.ghostR = 0
            sc.showCross = true
            sc.crossTarget = CGPoint(x: cx + 82, y: 176)
            sc.crossStart = CGPoint(x: 40, y: 60)
            sc.chip = bd ? "TOÀN THÂN + QUANH NGƯỜI" : "ĐẦU"
            spec("Collider thân/chi", bd ? "34 CapsuleCollider phình to" : "giữ nguyên (đã tắt tuỳ chọn)", wide: true)
            spec("Radius", fmt(rad, 6), hl: true); spec("Height", fmt(hgt, 6), hl: true)
            spec("Hitbox đầu", hd ? "phóng to thêm" : "giữ nguyên")
            spec("Khối cầu tàng hình", "≈ " + fmt(rad * 2, 1) + " m", hl: true); spec("File", "63.056 byte")
            sc.legend = [MakeSimLegend(color: sc.accent, text: "Khối cầu va chạm khổng lồ"),
                         MakeSimLegend(color: .white, text: "Bắn lệch ngoài người vẫn trúng")]

        // ---- Shader súng ----
        case "3":
            sc.kind = .gun
            sc.showGender = false
            sc.xray = color(store, "tXray", "#111111")
            sc.line = color(store, "tLine", "#FFFFFF")
            sc.dim = color(store, "tDim", "#111111")
            sc.lineWidth = CGFloat(store.raw("rWidth", 4))
            sc.xrayAlpha = store.raw("rAlpha", 1)
            sc.chip = "SÚNG · XUYÊN TƯỜNG"
            spec("_XRayColor", store.hex("tXray", "#111111").uppercased() + " · α " + fmt(sc.xrayAlpha, 2), hl: true)
            spec("_OutLineColor", store.hex("tLine", "#FFFFFF").uppercased(), hl: true)
            spec("_DimColor (keo)", store.hex("tDim", "#111111").uppercased())
            spec("_OutLineWidth", fmt(Double(sc.lineWidth), 1), hl: true)
            spec("Ghi vào", "m_DefValue · 16 byte / màu", wide: true); spec("File", "giữ nguyên dung lượng")
            sc.legend = [MakeSimLegend(color: sc.xray, text: "Thân súng"), MakeSimLegend(color: sc.line, text: "Viền"),
                         MakeSimLegend(color: sc.dim, text: "Keo (tay cầm, báng, ổ đạn)")]

        // ---- Hologram nhân vật ----
        default: // "4"
            sc.kind = .holo
            sc.tint = color(store, "tTint", "#00FFFF")
            sc.rim = color(store, "tRim", "#00FFFF")
            sc.scan = color(store, "tScan", "#000000")
            sc.tintA = store.raw("rTintA", 1); sc.rimA = store.raw("rRimA", 1); sc.scanA = store.raw("rScanA", 1)
            sc.xrayOn = store.flag("kXray"); sc.lineOn = store.flag("kLine"); sc.glitchOn = store.flag("kGlitch")
            sc.chip = sc.xrayOn ? "NHÂN VẬT XUYÊN TƯỜNG" : "BỊ TƯỜNG CHE"
            sc.note = sc.xrayOn ? "" : "zTest = LEqual: nhân vật bị tường che như bình thường"
            sc.showCross = false
            spec("_TintColor", store.hex("tTint", "#00FFFF").uppercased() + " · α " + fmt(sc.tintA, 2), hl: true)
            spec("_RimColor", store.hex("tRim", "#00FFFF").uppercased() + " · α " + fmt(sc.rimA, 2), hl: true)
            spec("_ScanColor", store.hex("tScan", "#000000").uppercased() + " · α " + fmt(sc.scanA, 2))
            spec("zTest", sc.xrayOn ? "8 (Always) — xuyên tường" : "4 (LEqual)", hl: sc.xrayOn)
            spec("Đường quét", sc.lineOn ? "bật (_Line)" : "tắt"); spec("Nhiễu / giật", sc.glitchOn ? "bật" : "tắt")
            sc.legend = [MakeSimLegend(color: sc.tint, text: "Thân hologram"), MakeSimLegend(color: sc.rim, text: "Sáng mép (fresnel rim)"),
                         MakeSimLegend(color: sc.scan, text: "Dải quét"), MakeSimLegend(color: Color(red: 0.48, green: 0.29, blue: 0.33), text: "Vật cản")]
        }
        return sc
    }

    static func trimNumber(_ v: Double) -> String {
        var s = String(format: "%.4f", v)
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
        return s
    }
}

// MARK: - Vẽ

private struct FigGeo {
    let female: Bool
    let sh: CGFloat
    let wa: CGFloat
    let hp: CGFloat
    let aw: CGFloat
    let lw: CGFloat

    init(_ g: MakeGender) {
        let f = g == .female
        female = f
        sh = f ? 38 : 46
        wa = f ? 19 : 25
        hp = f ? 31 : 27
        aw = f ? 12 : 15
        lw = f ? 23 : 26
    }

    func arm(_ s: CGFloat) -> [CGPoint] {
        let c = MakeSimBuilder.cx
        return [CGPoint(x: c + s * (sh - 2), y: 112), CGPoint(x: c + s * (sh + 12), y: 186), CGPoint(x: c + s * (sh + 17), y: 240)]
    }

    func leg(_ s: CGFloat) -> [CGPoint] {
        let c = MakeSimBuilder.cx
        return [CGPoint(x: c + s * hp * 0.5, y: 252), CGPoint(x: c + s * hp * 0.62, y: 334), CGPoint(x: c + s * hp * 0.68, y: 402)]
    }

    var torso: Path {
        let c = MakeSimBuilder.cx
        var p = Path()
        p.move(to: CGPoint(x: c - sh, y: 108))
        p.addQuadCurve(to: CGPoint(x: c + sh, y: 108), control: CGPoint(x: c, y: 94))
        p.addLine(to: CGPoint(x: c + wa + 3, y: 190))
        p.addQuadCurve(to: CGPoint(x: c + hp, y: 256), control: CGPoint(x: c + wa + 6, y: 222))
        p.addLine(to: CGPoint(x: c - hp, y: 256))
        p.addQuadCurve(to: CGPoint(x: c - wa - 3, y: 190), control: CGPoint(x: c - wa - 6, y: 222))
        p.closeSubpath()
        return p
    }

    /// Các khối đặc: thân, cổ, đầu, bàn tay, bàn chân
    var solids: [Path] {
        let c = MakeSimBuilder.cx
        var list: [Path] = [torso]
        list.append(Path(roundedRect: CGRect(x: c - 8, y: 70, width: 16, height: 30), cornerRadius: 6))
        list.append(Path(ellipseIn: CGRect(x: c - 20, y: 28, width: 40, height: 48)))
        for s in [CGFloat(-1), CGFloat(1)] {
            let h = arm(s)[2]
            let r = aw * 0.62
            list.append(Path(ellipseIn: CGRect(x: h.x - r, y: h.y + 6 - r, width: 2 * r, height: 2 * r)))
            let f = leg(s)[2]
            let fxp = f.x + (f.x < c ? -3 : 3)
            list.append(Path(ellipseIn: CGRect(x: fxp - 13, y: 400, width: 26, height: 12)))
        }
        return list
    }

    /// Tay + chân là các đường dày
    var limbs: [(pts: [CGPoint], w: CGFloat)] {
        var out: [(pts: [CGPoint], w: CGFloat)] = []
        for s in [CGFloat(-1), CGFloat(1)] {
            out.append((arm(s), aw))
            out.append((leg(s), lw))
        }
        return out
    }
}

private func polyline(_ pts: [CGPoint]) -> Path {
    var p = Path()
    guard let first = pts.first else { return p }
    p.move(to: first)
    for q in pts.dropFirst() { p.addLine(to: q) }
    return p
}

private func circlePath(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
}

private func roundStyle(_ w: CGFloat) -> StrokeStyle {
    StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
}

private func smooth(_ x: Double) -> Double {
    let c = Swift.max(0, Swift.min(1, x))
    return c * c * (3 - 2 * c)
}

/// 1 = tâm ngắm ở vị trí xuất phát, 0 = đã khoá vào vùng aim
private func pullFactor(_ phase: Double) -> Double {
    if phase < 0.22 { return 1 }
    if phase < 0.52 { return 1 - smooth((phase - 0.22) / 0.30) }
    if phase < 0.86 { return 0 }
    return smooth((phase - 0.86) / 0.14)
}

private func tagAlpha(_ phase: Double) -> Double {
    if phase < 0.50 { return 0 }
    if phase < 0.58 { return (phase - 0.50) / 0.08 }
    if phase < 0.86 { return 1 }
    if phase < 0.94 { return 1 - (phase - 0.86) / 0.08 }
    return 0
}

struct MakeSimCanvas: View {
    let scene: MakeSimScene
    var mini = false
    var animated = true

    private var fillColor: Color { Color(red: 0.122, green: 0.192, blue: 0.349) }
    private var edgeColor: Color { Color(red: 0.373, green: 0.533, blue: 0.800) }

    var body: some View {
        if mini || !animated {
            Canvas { ctx, size in
                render(&ctx, size, t: 0)
            }
        } else {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    render(&ctx, size, t: tl.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    private func render(_ ctx: inout GraphicsContext, _ size: CGSize, t: Double) {
        let vb = mini ? scene.thumbBox : scene.stageBox
        let s = Swift.min(size.width / vb.width, size.height / vb.height)
        ctx.translateBy(x: (size.width - vb.width * s) / 2, y: (size.height - vb.height * s) / 2)
        ctx.scaleBy(x: s, y: s)
        ctx.translateBy(x: -vb.minX, y: -vb.minY)

        switch scene.kind {
        case .figure: drawFigureScene(&ctx, t)
        case .gun: drawGunScene(&ctx, t)
        case .holo: drawHoloScene(&ctx, t)
        }
    }

    // MARK: hình người

    private func drawBody(_ ctx: inout GraphicsContext, fill: Color, edge: Color, fillOpacity: Double = 1,
                          edgeOpacity: Double = 1, glow: Color? = nil, shade: Bool = true, bones: Bool = true) {
        let geo = FigGeo(scene.gender)
        let solids = geo.solids
        let limbs = geo.limbs

        ctx.drawLayer { l in
            l.opacity = edgeOpacity
            if let g = glow, !mini { l.addFilter(.shadow(color: g.opacity(0.9), radius: 5, x: 0, y: 0)) }
            for lb in limbs { l.stroke(polyline(lb.pts), with: .color(edge), style: roundStyle(lb.w + 3)) }
            for p in solids {
                l.fill(p, with: .color(edge))
                l.stroke(p, with: .color(edge), style: roundStyle(3))
            }
        }
        ctx.drawLayer { l in
            l.opacity = fillOpacity
            for lb in limbs { l.stroke(polyline(lb.pts), with: .color(fill), style: roundStyle(lb.w)) }
            for p in solids { l.fill(p, with: .color(fill)) }
            if geo.female {
                let c = MakeSimBuilder.cx
                var hair = Path()
                hair.move(to: CGPoint(x: c - 21, y: 52))
                hair.addQuadCurve(to: CGPoint(x: c, y: 26), control: CGPoint(x: c - 24, y: 24))
                hair.addQuadCurve(to: CGPoint(x: c + 21, y: 52), control: CGPoint(x: c + 24, y: 24))
                hair.addQuadCurve(to: CGPoint(x: c, y: 36), control: CGPoint(x: c + 13, y: 36))
                hair.addQuadCurve(to: CGPoint(x: c - 21, y: 52), control: CGPoint(x: c - 13, y: 36))
                l.fill(hair, with: .color(edge))
                var tail = Path()
                tail.move(to: CGPoint(x: c + 16, y: 34))
                tail.addQuadCurve(to: CGPoint(x: c + 40, y: 100), control: CGPoint(x: c + 48, y: 42))
                tail.addQuadCurve(to: CGPoint(x: c + 18, y: 60), control: CGPoint(x: c + 32, y: 66))
                tail.closeSubpath()
                l.fill(tail, with: .color(edge))
            }
        }
        if shade {
            let grad = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0)]),
                startPoint: CGPoint(x: 0, y: 20), endPoint: CGPoint(x: 0, y: 410))
            ctx.drawLayer { l in
                l.opacity = fillOpacity
                for lb in limbs { l.stroke(polyline(lb.pts), with: grad, style: roundStyle(lb.w)) }
                for p in solids { l.fill(p, with: grad) }
            }
        }
        if bones && !mini { drawBones(&ctx, geo) }
    }

    private func drawBones(_ ctx: inout GraphicsContext, _ geo: FigGeo) {
        let c = MakeSimBuilder.cx
        var lines: [(CGPoint, CGPoint)] = [
            (CGPoint(x: c, y: 52), CGPoint(x: c, y: 92)), (CGPoint(x: c, y: 92), CGPoint(x: c, y: 252)),
            (CGPoint(x: c - geo.sh + 2, y: 112), CGPoint(x: c + geo.sh - 2, y: 112))
        ]
        var joints: [CGPoint] = [CGPoint(x: c, y: 52), CGPoint(x: c, y: 92), CGPoint(x: c, y: 190), CGPoint(x: c, y: 252)]
        for s in [CGFloat(-1), CGFloat(1)] {
            let a = geo.arm(s)
            let l = geo.leg(s)
            lines.append((a[0], a[1])); lines.append((a[1], a[2]))
            lines.append((CGPoint(x: c, y: 252), l[0])); lines.append((l[0], l[1])); lines.append((l[1], l[2]))
            joints.append(contentsOf: a); joints.append(contentsOf: l)
        }
        var lp = Path()
        for ln in lines { lp.move(to: ln.0); lp.addLine(to: ln.1) }
        ctx.stroke(lp, with: .color(Color.white.opacity(0.2)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        for j in joints { ctx.fill(circlePath(j.x, j.y, 2), with: .color(Color.white.opacity(0.55))) }
    }

    private func drawRuler(_ ctx: inout GraphicsContext) {
        if mini { return }
        let marks: [(CGFloat, String)] = [(36, "ĐỈNH ĐẦU"), (74, "CẰM"), (98, "CỔ"), (150, "NGỰC"), (200, "BỤNG"), (250, "HÔNG")]
        let col = Color(red: 0.58, green: 0.64, blue: 0.72)
        for m in marks {
            var p = Path()
            p.move(to: CGPoint(x: 6, y: m.0)); p.addLine(to: CGPoint(x: 21, y: m.0))
            ctx.stroke(p, with: .color(col.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            ctx.draw(Text(m.1).font(.system(size: 7.5, weight: .semibold, design: .monospaced)).foregroundColor(col.opacity(0.85)),
                     at: CGPoint(x: 24, y: m.0 + 2.6), anchor: .leading)
        }
    }

    private func drawColliders(_ ctx: inout GraphicsContext, mode: MakeColliderMode) {
        if mode == .none { return }
        let geo = FigGeo(scene.gender)
        let c = MakeSimBuilder.cx
        var seg: [(CGPoint, CGPoint, CGFloat)] = [
            (CGPoint(x: c, y: 128), CGPoint(x: c, y: 168), 26), (CGPoint(x: c, y: 182), CGPoint(x: c, y: 218), 22),
            (CGPoint(x: c, y: 240), CGPoint(x: c, y: 250), 27)
        ]
        for s in [CGFloat(-1), CGFloat(1)] {
            seg.append((CGPoint(x: c + s * (geo.sh + 3), y: 120), CGPoint(x: c + s * (geo.sh + 11), y: 170), 9))
            seg.append((CGPoint(x: c + s * (geo.sh + 13), y: 190), CGPoint(x: c + s * (geo.sh + 17), y: 236), 8))
            seg.append((CGPoint(x: c + s * geo.hp * 0.5, y: 264), CGPoint(x: c + s * geo.hp * 0.6, y: 322), 13))
            seg.append((CGPoint(x: c + s * geo.hp * 0.62, y: 342), CGPoint(x: c + s * geo.hp * 0.67, y: 392), 11))
        }
        ctx.drawLayer { l in
            l.opacity = mode == .off ? 0.05 : 0.17
            for s in seg {
                var p = Path()
                p.move(to: s.0); p.addLine(to: s.1)
                l.stroke(p, with: .color(MakeSimBuilder.colColor), style: roundStyle(s.2 * 2))
            }
        }
    }

    private func drawGhost(_ ctx: inout GraphicsContext, r: CGFloat) {
        if r <= 0 { return }
        ctx.stroke(circlePath(MakeSimBuilder.cx, 52, r), with: .color(MakeSimBuilder.ghostColor.opacity(0.75)),
                   style: StrokeStyle(lineWidth: 1.3, dash: [3, 3]))
    }

    private func drawZone(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, r: CGFloat, t: Double) {
        let color = scene.accent
        ctx.fill(circlePath(x, y, r), with: .color(color.opacity(0.17)))
        if !mini {
            let ph = t.truncatingRemainder(dividingBy: 2.2) / 2.2
            let sc = CGFloat(0.85 + 0.65 * ph)
            ctx.stroke(circlePath(x, y, r * sc), with: .color(color.opacity(0.7 * (1 - ph))), lineWidth: 1.4)
        }
        ctx.drawLayer { l in
            if !mini { l.addFilter(.shadow(color: color.opacity(0.8), radius: 4, x: 0, y: 0)) }
            l.stroke(circlePath(x, y, r), with: .color(color),
                     style: StrokeStyle(lineWidth: 2, dash: [6, 5], dashPhase: CGFloat(-t * 14)))
        }
        ctx.fill(circlePath(x, y, 3), with: .color(color))
        var ticks = Path()
        ticks.move(to: CGPoint(x: x - r - 5, y: y)); ticks.addLine(to: CGPoint(x: x - r + 5, y: y))
        ticks.move(to: CGPoint(x: x + r - 5, y: y)); ticks.addLine(to: CGPoint(x: x + r + 5, y: y))
        ticks.move(to: CGPoint(x: x, y: y - r - 5)); ticks.addLine(to: CGPoint(x: x, y: y - r + 5))
        ticks.move(to: CGPoint(x: x, y: y + r - 5)); ticks.addLine(to: CGPoint(x: x, y: y + r + 5))
        ctx.stroke(ticks, with: .color(color), style: roundStyle(1.5))
    }

    private func drawSwoosh(_ ctx: inout GraphicsContext, y: CGFloat, r: CGFloat, t: Double) {
        if y <= 76 || r <= 0 { return }
        let c = MakeSimBuilder.cx
        var p = Path()
        p.move(to: CGPoint(x: c + 21, y: 58))
        p.addQuadCurve(to: CGPoint(x: c + r * 0.72, y: y - r * 0.72), control: CGPoint(x: c + r + 40, y: (52 + y) / 2))
        ctx.stroke(p, with: .color(scene.accent.opacity(0.85)),
                   style: StrokeStyle(lineWidth: 1.6, dash: [4, 5], dashPhase: CGFloat(-t * 16)))
        ctx.fill(circlePath(c + r * 0.72, y - r * 0.72, 2.6), with: .color(scene.accent))
    }

    private func drawToeLink(_ ctx: inout GraphicsContext, y: CGFloat, r: CGFloat, t: Double) {
        let geo = FigGeo(scene.gender)
        let fx0 = MakeSimBuilder.cx - geo.hp * 0.68 - 3
        var p = Path()
        p.move(to: CGPoint(x: fx0, y: 400))
        p.addCurve(to: CGPoint(x: MakeSimBuilder.cx - r * 0.7, y: y + r * 0.3),
                   control1: CGPoint(x: fx0 - 58, y: 330), control2: CGPoint(x: fx0 - 58, y: y + 52))
        ctx.stroke(p, with: .color(scene.accent.opacity(0.8)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5], dashPhase: CGFloat(-t * 16)))
        if !mini {
            ctx.draw(Text("bone_LeftToe").font(.system(size: 7.5, weight: .semibold, design: .monospaced)).foregroundColor(scene.accent),
                     at: CGPoint(x: fx0 - 32, y: 415), anchor: .leading)
        }
    }

    private func drawBeam(_ ctx: inout GraphicsContext, t: Double) {
        let h = scene.beam
        if h < 2 { return }
        let geo = FigGeo(scene.gender)
        let male = scene.gender == .male
        let x = male ? MakeSimBuilder.cx - (geo.sh + 17) : MakeSimBuilder.cx + (geo.sh + 17)
        let hy: CGFloat = 236
        let top = hy - CGFloat(Swift.min(h, 250) / 250 * 270)
        let ant = MakeSimBuilder.ant
        let rect = Path(CGRect(x: x - 4, y: top, width: 8, height: hy - top))
        ctx.drawLayer { l in
            if !mini { l.addFilter(.shadow(color: ant.opacity(0.9), radius: 5, x: 0, y: 0)) }
            l.fill(rect, with: .linearGradient(Gradient(colors: [ant.opacity(0.15), ant.opacity(0.95)]),
                                               startPoint: CGPoint(x: x, y: top), endPoint: CGPoint(x: x, y: hy)))
        }
        var ln = Path()
        ln.move(to: CGPoint(x: x, y: hy)); ln.addLine(to: CGPoint(x: x, y: top))
        ctx.stroke(ln, with: .color(Color.white.opacity(0.85)), style: StrokeStyle(lineWidth: 2, dash: [5, 13], dashPhase: CGFloat(-t * 40)))
        if top < 30 && !mini {
            for (i, r) in [CGFloat(7), 12, 17].enumerated() {
                let ph = ((t * 0.625) + Double(i) * 0.22).truncatingRemainder(dividingBy: 1)
                var arc = Path()
                arc.addArc(center: CGPoint(x: x, y: 34), radius: r, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                ctx.drawLayer { l in
                    l.opacity = 0.9 * (1 - ph)
                    l.stroke(arc, with: .color(ant), style: roundStyle(1.8))
                }
            }
        }
        if !mini {
            ctx.draw(Text("e33 = " + String(format: "%.1f", h)).font(.system(size: 7.5, weight: .semibold, design: .monospaced)).foregroundColor(ant),
                     at: CGPoint(x: male ? x - 12 : x + 12, y: 150), anchor: male ? .trailing : .leading)
        }
    }

    private func drawCross(_ ctx: inout GraphicsContext, t: Double) {
        if mini || !scene.showCross { return }
        let phase = t.truncatingRemainder(dividingBy: 3.6) / 3.6
        let f = CGFloat(pullFactor(phase))
        let p = CGPoint(x: scene.crossTarget.x + scene.crossStart.x * f, y: scene.crossTarget.y + scene.crossStart.y * f)
        ctx.stroke(circlePath(p.x, p.y, 11), with: .color(.white), lineWidth: 1.6)
        var cross = Path()
        cross.move(to: CGPoint(x: p.x - 19, y: p.y)); cross.addLine(to: CGPoint(x: p.x - 6, y: p.y))
        cross.move(to: CGPoint(x: p.x + 6, y: p.y)); cross.addLine(to: CGPoint(x: p.x + 19, y: p.y))
        cross.move(to: CGPoint(x: p.x, y: p.y - 19)); cross.addLine(to: CGPoint(x: p.x, y: p.y - 6))
        cross.move(to: CGPoint(x: p.x, y: p.y + 6)); cross.addLine(to: CGPoint(x: p.x, y: p.y + 19))
        ctx.stroke(cross, with: .color(.white), style: roundStyle(1.6))
        ctx.fill(circlePath(p.x, p.y, 2.2), with: .color(Color(red: 1, green: 0.23, blue: 0.36)))

        let a = tagAlpha(phase)
        if a > 0 {
            let zr = scene.zoneR
            let tx = Swift.min(scene.zoneX + zr + 4, 226)
            let ty = Swift.max(scene.zoneY - zr - 12, 30)
            ctx.drawLayer { l in
                l.opacity = a
                let rect = CGRect(x: tx, y: ty - 11, width: 72, height: 17)
                l.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Color(red: 0.94, green: 0.14, blue: 0.24)))
                l.draw(Text("HEADSHOT").font(.system(size: 10, weight: .heavy)).foregroundColor(.white),
                       at: CGPoint(x: tx + 36, y: ty - 2.5), anchor: .center)
            }
        }
    }

    private func drawFigureScene(_ ctx: inout GraphicsContext, _ t: Double) {
        drawRuler(&ctx)
        if scene.giantRV > 0 {
            let geo = FigGeo(scene.gender)
            let c = MakeSimBuilder.cx
            let pts: [CGPoint] = [
                CGPoint(x: c, y: 92), CGPoint(x: c, y: 140), CGPoint(x: c, y: 200), CGPoint(x: c, y: 250),
                CGPoint(x: c - geo.sh + 2, y: 112), CGPoint(x: c + geo.sh - 2, y: 112),
                CGPoint(x: c - geo.sh - 12, y: 186), CGPoint(x: c + geo.sh + 12, y: 186),
                CGPoint(x: c - geo.sh - 17, y: 240), CGPoint(x: c + geo.sh + 17, y: 240),
                CGPoint(x: c - geo.hp * 0.6, y: 334), CGPoint(x: c + geo.hp * 0.6, y: 334),
                CGPoint(x: c - geo.hp * 0.67, y: 402), CGPoint(x: c + geo.hp * 0.67, y: 402),
                CGPoint(x: c - geo.hp * 0.5, y: 290), CGPoint(x: c + geo.hp * 0.5, y: 290)
            ]
            let rv = scene.giantRV
            for p in pts {
                let e = Path(ellipseIn: CGRect(x: p.x - rv, y: p.y - rv - scene.giantH, width: rv * 2, height: (rv + scene.giantH) * 2))
                ctx.fill(e, with: .color(scene.accent.opacity(0.085)))
                ctx.stroke(e, with: .color(scene.accent.opacity(0.5)), lineWidth: 1.3)
            }
        } else {
            drawColliders(&ctx, mode: scene.colliders)
        }
        drawGhost(&ctx, r: scene.ghostR)
        drawBody(&ctx, fill: fillColor, edge: edgeColor)

        if scene.hasZone {
            drawSwoosh(&ctx, y: scene.zoneY, r: scene.zoneR, t: t)
            if scene.toeLink { drawToeLink(&ctx, y: scene.zoneY, r: scene.zoneR, t: t) }
            drawZone(&ctx, x: scene.zoneX, y: scene.zoneY, r: scene.zoneR, t: t)
            if scene.swap && !mini {
                let acc = scene.accent
                ctx.draw(Text("bone_Hips").font(.system(size: 7.5, weight: .semibold, design: .monospaced)).foregroundColor(acc),
                         at: CGPoint(x: 238, y: 99), anchor: .leading)
                ctx.draw(Text("bone_Neck").font(.system(size: 7.5, weight: .semibold, design: .monospaced)).foregroundColor(acc),
                         at: CGPoint(x: 238, y: 247), anchor: .leading)
                var p = Path()
                p.move(to: CGPoint(x: 234, y: 104))
                p.addQuadCurve(to: CGPoint(x: 234, y: 240), control: CGPoint(x: 266, y: 172))
                ctx.stroke(p, with: .color(MakeSimBuilder.ghostColor), style: StrokeStyle(lineWidth: 1.4, dash: [4, 5], dashPhase: CGFloat(-t * 16)))
            }
        }
        if scene.beam > 0 { drawBeam(&ctx, t: t) }
        drawCross(&ctx, t: t)
    }

    // MARK: súng X-Ray

    private func drawWall(_ ctx: inout GraphicsContext, _ rect: CGRect) {
        ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(red: 0.23, green: 0.16, blue: 0.19), Color(red: 0.14, green: 0.10, blue: 0.15)]),
                                                   startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        var lines = Path()
        var y = rect.minY
        var row = 0
        while y <= rect.maxY {
            lines.move(to: CGPoint(x: rect.minX, y: y)); lines.addLine(to: CGPoint(x: rect.maxX, y: y))
            if y + 18 <= rect.maxY {
                var x = rect.minX + (row % 2 == 0 ? 0 : 18)
                while x <= rect.maxX {
                    lines.move(to: CGPoint(x: x, y: y)); lines.addLine(to: CGPoint(x: x, y: y + 18))
                    x += 36
                }
            }
            y += 18
            row += 1
        }
        ctx.stroke(lines, with: .color(Color.black.opacity(0.45)), lineWidth: 1.2)
        ctx.fill(Path(rect), with: .color(Color.black.opacity(0.22)))
        ctx.stroke(Path(rect), with: .color(Color.white.opacity(0.12)), lineWidth: 1)
    }

    private func drawGunScene(_ ctx: inout GraphicsContext, _ t: Double) {
        drawWall(&ctx, CGRect(x: 14, y: 150, width: 278, height: 150))

        let main: [Path] = [
            Path(CGRect(x: 20, y: 193, width: 12, height: 13)),
            Path(CGRect(x: 30, y: 196, width: 70, height: 7)),
            polygon([(98, 190), (170, 188), (170, 210), (98, 210)]),
            Path(CGRect(x: 168, y: 184, width: 66, height: 27)),
            Path(CGRect(x: 180, y: 175, width: 44, height: 9)),
            Path(CGRect(x: 32, y: 186, width: 5, height: 10))
        ]
        var mag = Path()
        mag.move(to: CGPoint(x: 188, y: 210))
        mag.addLine(to: CGPoint(x: 216, y: 210))
        mag.addQuadCurve(to: CGPoint(x: 226, y: 266), control: CGPoint(x: 232, y: 240))
        mag.addLine(to: CGPoint(x: 202, y: 262))
        mag.addQuadCurve(to: CGPoint(x: 188, y: 210), control: CGPoint(x: 204, y: 236))
        mag.closeSubpath()
        let dimS: [Path] = [
            mag,
            polygon([(224, 210), (244, 210), (253, 250), (237, 253)]),
            polygon([(232, 186), (288, 196), (288, 226), (250, 220), (232, 210)])
        ]

        ctx.drawLayer { l in
            if !mini { l.addFilter(.shadow(color: scene.line.opacity(0.7), radius: 5, x: 0, y: 0)) }
            l.translateBy(x: -2, y: 0)
            l.scaleBy(x: 0.96, y: 0.96)
            l.translateBy(x: 155, y: 226)
            l.rotate(by: .degrees(-5))
            l.translateBy(x: -155, y: -226)
            let w = scene.lineWidth
            for p in main + dimS {
                l.fill(p, with: .color(scene.line))
                l.stroke(p, with: .color(scene.line), style: roundStyle(w * 2))
            }
            for p in main { l.fill(p, with: .color(scene.xray.opacity(scene.xrayAlpha))) }
            for p in dimS { l.fill(p, with: .color(scene.dim)) }
        }
        if !mini {
            ctx.draw(Text("BỨC TƯỜNG").font(.system(size: 7.5, weight: .semibold, design: .monospaced)).foregroundColor(MakeSimBuilder.ghostColor),
                     at: CGPoint(x: 22, y: 140), anchor: .leading)
            ctx.draw(Text("SÚNG ĐỊCH HIỆN QUA TƯỜNG").font(.system(size: 7.5, weight: .semibold, design: .monospaced)).foregroundColor(scene.accent),
                     at: CGPoint(x: 22, y: 312), anchor: .leading)
        }
    }

    private func polygon(_ pts: [(CGFloat, CGFloat)]) -> Path {
        var p = Path()
        for (i, q) in pts.enumerated() {
            if i == 0 { p.move(to: CGPoint(x: q.0, y: q.1)) } else { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
        }
        p.closeSubpath()
        return p
    }

    // MARK: hologram

    private func drawHoloScene(_ ctx: inout GraphicsContext, _ t: Double) {
        drawRuler(&ctx)
        let wallRect = CGRect(x: 66, y: 122, width: 168, height: 288)
        let holo: (inout GraphicsContext) -> Void = { c in
            drawBody(&c, fill: scene.tint, edge: scene.rim, fillOpacity: scene.tintA, edgeOpacity: scene.rimA, glow: scene.rim, shade: true, bones: false)
        }
        if scene.xrayOn {
            drawWall(&ctx, wallRect)
            holo(&ctx)
        } else {
            holo(&ctx)
            drawWall(&ctx, wallRect)
        }
        if mini { return }

        let geo = FigGeo(scene.gender)
        var mask = Path()
        for p in geo.solids { mask.addPath(p) }
        for lb in geo.limbs { mask.addPath(polyline(lb.pts).strokedPath(roundStyle(lb.w + 3))) }

        if scene.lineOn {
            ctx.drawLayer { l in
                l.clip(to: mask)
                var y: CGFloat = 20
                while y < 420 {
                    l.fill(Path(CGRect(x: 40, y: y, width: 220, height: 2)), with: .color(Color(red: 0.01, green: 0.02, blue: 0.05).opacity(0.6)))
                    y += 6
                }
            }
        }
        if scene.glitchOn {
            let bands: [(CGRect, Double, Double)] = [(CGRect(x: 0, y: 118, width: 300, height: 20), 2.4, 8), (CGRect(x: 0, y: 200, width: 300, height: 16), 2.9, -9)]
            for b in bands {
                let ph = t.truncatingRemainder(dividingBy: b.1) / b.1
                let dx: CGFloat = (ph > 0.18 && ph < 0.26) ? CGFloat(b.2) : ((ph > 0.68 && ph < 0.74) ? CGFloat(-b.2) : 0)
                if dx == 0 { continue }
                ctx.drawLayer { l in
                    l.clip(to: Path(b.0))
                    l.translateBy(x: dx, y: 0)
                    drawBody(&l, fill: scene.tint, edge: scene.rim, fillOpacity: scene.tintA, edgeOpacity: scene.rimA, glow: nil, shade: false, bones: false)
                }
            }
        }
        if scene.scanA > 0 && !isBlack(scene.scan) {
            let ph = t.truncatingRemainder(dividingBy: 3.2) / 3.2
            let y = CGFloat(10 + ph * 420)
            ctx.drawLayer { l in
                l.clip(to: mask)
                l.fill(Path(CGRect(x: 40, y: y, width: 220, height: 30)), with: .color(scene.scan.opacity(Swift.min(0.85, scene.scanA * 0.7))))
            }
        }
    }

    private func isBlack(_ c: Color) -> Bool {
        let ui = UIColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r < 0.01 && g < 0.01 && b < 0.01
    }
}

// MARK: - Khung mô phỏng lớn (có kéo thả)

struct MakeSimStage: View {
    @ObservedObject var store: MakeToolsStore
    let scene: MakeSimScene

    var body: some View {
        GeometryReader { geo in
            MakeSimCanvas(scene: scene)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let vb = scene.stageBox
                            let s = Swift.min(geo.size.width / vb.width, geo.size.height / vb.height)
                            let offY = (geo.size.height - vb.height * s) / 2
                            let y = Double(vb.minY + (v.location.y - offY) / s)
                            store.dragTo(y: y)
                        },
                    including: store.isDraggable ? .all : .none)
        }
    }
}
