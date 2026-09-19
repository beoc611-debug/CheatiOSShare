import SwiftUI

// MARK: - Nhóm + huy hiệu

enum MakeCategory: String, CaseIterable, Identifiable {
    case aimlock, antena, magic, hitbox, shader

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aimlock: return "Aimlock"
        case .antena: return "Antena & Studio"
        case .magic: return "Magic Bullet"
        case .hitbox: return "Hitbox cache_res"
        case .shader: return "Shader"
        }
    }

    var color: Color {
        switch self {
        case .aimlock: return Color(red: 0.13, green: 0.90, blue: 1.00)
        case .antena: return Color(red: 0.98, green: 0.75, blue: 0.14)
        case .magic: return Color(red: 0.98, green: 0.44, blue: 0.52)
        case .hitbox: return Color(red: 0.20, green: 0.83, blue: 0.60)
        case .shader: return Color(red: 0.65, green: 0.55, blue: 0.98)
        }
    }
}

enum MakeBadgeStyle {
    case magic, safe, antena, studio, shader, hitbox, uma, model

    var color: Color {
        switch self {
        case .magic: return Color(red: 0.98, green: 0.44, blue: 0.52)
        case .safe: return Color(red: 0.49, green: 0.83, blue: 0.99)
        case .antena: return Color(red: 0.99, green: 0.83, blue: 0.30)
        case .studio: return Color(red: 0.86, green: 0.75, blue: 1.00)
        case .shader: return Color(red: 0.65, green: 0.71, blue: 0.99)
        case .hitbox: return Color(red: 0.89, green: 0.91, blue: 0.94)
        case .uma: return Color(red: 0.58, green: 0.64, blue: 0.72)
        case .model: return Color(red: 0.20, green: 0.83, blue: 0.60)
        }
    }
}

struct MakeBadge: Identifiable {
    let text: String
    let style: MakeBadgeStyle
    var id: String { text }
}

// MARK: - Ô tùy chỉnh

struct MakeField: Identifiable {
    enum Kind { case number, toggle, slider, color }

    let id: String
    let label: String
    var hint: String = ""
    var kind: Kind = .number
    var num: Double = 0
    var flag: Bool = false
    var hex: String = "#FFFFFF"
    var range: ClosedRange<Double> = 0...1
    var step: Double = 0.05

    static func n(_ id: String, _ label: String, _ def: Double, hint: String = "") -> MakeField {
        MakeField(id: id, label: label, hint: hint, kind: .number, num: def)
    }
    static func t(_ id: String, _ label: String, _ def: Bool, hint: String = "") -> MakeField {
        MakeField(id: id, label: label, hint: hint, kind: .toggle, flag: def)
    }
    static func c(_ id: String, _ label: String, _ hex: String, hint: String = "") -> MakeField {
        MakeField(id: id, label: label, hint: hint, kind: .color, hex: hex)
    }
    static func s(_ id: String, _ label: String, _ def: Double, _ range: ClosedRange<Double>, _ step: Double, hint: String = "") -> MakeField {
        MakeField(id: id, label: label, hint: hint, kind: .slider, num: def, range: range, step: step)
    }
}

// MARK: - Preset

struct MakePreset: Identifiable {
    let id: String
    let category: MakeCategory
    let name: String
    let line: String
    let desc: String
    let need: MakeBundleKind
    let needLabel: String
    let badges: [MakeBadge]
    var tuneTitle: String = ""
    var fields: [MakeField] = []

    var number: String { id.count < 2 ? "0" + id : id }
}

enum MakeToolsCatalog {
    static let all: [MakePreset] = [
        MakePreset(id: "1", category: .magic, name: "Dị Tật Aim Head", line: "Hoán đổi xương Hips ⇄ Neck",
                   desc: "Tráo tên + CRC32 của bone_Hips ⇄ bone_Neck trong toàn bundle. Vùng tính headshot bị lệch khỏi đầu, rơi xuống hông.",
                   need: .uma, needLabel: "assetindexer", badges: [MakeBadge(text: "DỊ TẬT", style: .magic), MakeBadge(text: "UMA", style: .uma)]),

        MakePreset(id: "2", category: .magic, name: "AimDrag Cân Cap USP", line: "Đầu giả dời xuống cằm/cổ",
                   desc: "Dựng lại bundle, dời bone_Head phụ xuống dưới đầu và phóng theo scale (x âm hơn = cao hơn). Kéo tâm lên là chớm headshot — cân cho USP / súng cap.",
                   need: .uma, needLabel: "assetindexer", badges: [MakeBadge(text: "AIMDRAG CAP", style: .magic), MakeBadge(text: "UMA", style: .uma)],
                   tuneTitle: "Tinh chỉnh preset 2",
                   fields: [.n("fx", "Nữ · position.x", -0.23), .n("fz", "Nữ · position.z", -0.01),
                            .n("mx", "Nam · position.x", -0.3133402466773987), .n("sc", "Scale (x âm)", 1.5555556)]),

        MakePreset(id: "3", category: .shader, name: "Định vị súng", line: "Súng phát sáng xuyên tường",
                   desc: "Ghi màu RGBA vào m_DefValue của shader súng: màu thân, màu viền + độ dày viền, màu keo. Kích thước file giữ nguyên.",
                   need: .shader, needLabel: "shaders", badges: [MakeBadge(text: "X-RAY SÚNG", style: .shader), MakeBadge(text: "SHADER", style: .shader)],
                   tuneTitle: "Màu preset 3",
                   fields: [.c("tXray", "Màu súng (_XRayColor)", "#111111"), .c("tLine", "Màu viền súng (_OutLineColor)", "#FFFFFF"),
                            .c("tDim", "Màu keo (_DimColor)", "#111111"),
                            .s("rWidth", "Độ dày viền (_OutLineWidth)", 4, 0...20, 0.5),
                            .s("rAlpha", "Độ đục màu súng (alpha)", 1, 0...1, 0.05)]),

        MakePreset(id: "4", category: .shader, name: "Định vị nhân vật", line: "Hologram nhìn xuyên vật cản",
                   desc: "Thay shader nhân vật bằng hologram: zTest = Always cho xuyên tường, kèm màu thân, sáng mép fresnel, dải quét, đường kẻ và nhiễu.",
                   need: .holo, needLabel: "hologram", badges: [MakeBadge(text: "HOLOGRAM", style: .shader), MakeBadge(text: "SHADER", style: .shader)],
                   tuneTitle: "Màu preset 4",
                   fields: [.c("tTint", "Màu nhân vật (_TintColor)", "#00FFFF"), .c("tRim", "Màu sáng mép (_RimColor)", "#00FFFF"),
                            .c("tScan", "Màu quét (_ScanColor)", "#000000"),
                            .s("rTintA", "Độ đục nhân vật", 1, 0...1, 0.05), .s("rRimA", "Độ mạnh sáng mép", 1, 0...1, 0.05),
                            .s("rScanA", "Độ mạnh quét", 1, 0...1, 0.05),
                            .t("kXray", "Xuyên tường (zTest = Always)", true), .t("kLine", "Đường quét ngang (_Line)", false),
                            .t("kGlitch", "Nhiễu / giật (_LineAndGlitch)", false)]),

        MakePreset(id: "5", category: .aimlock, name: "Aimlock Đỉnh Đầu", line: "Tâm khoá lên đỉnh đầu",
                   desc: "Đổi bone_Left_Weapon thành bone_Head (cha bone_Spine1) và kéo bone_LeftToe lên đỉnh đầu, scale 1.5. Khớp 100% File 1.",
                   need: .uma, needLabel: "assetindexer", badges: [MakeBadge(text: "HEAD LOCK", style: .safe), MakeBadge(text: "UMA", style: .uma)],
                   tuneTitle: "Tinh chỉnh preset 5",
                   fields: [.n("aimToeScale", "bone_LeftToe · scale", 1.5), .n("aimToeX", "bone_LeftToe · position.x", -0.3850825),
                            .n("aimToeY", "bone_LeftToe · position.y", -0.0746385),
                            .t("aimMale", "Mesh nam", true), .t("aimFemale", "Mesh nữ", false)]),

        MakePreset(id: "6", category: .antena, name: "Antena Tay", line: "Cột sóng định vị từ bàn tay",
                   desc: "Kéo bindPoses[4].e33 từ 1.0 lên 250.0 — bàn tay phóng một cột sóng thẳng lên trời để định vị đối thủ từ xa (nam: tay phải, nữ: tay trái).",
                   need: .uma, needLabel: "assetindexer", badges: [MakeBadge(text: "CỘT SÓNG x250", style: .antena), MakeBadge(text: "UMA", style: .uma)],
                   tuneTitle: "Tinh chỉnh preset 6",
                   fields: [.n("antenaHeight", "Độ cao / tỉ lệ Antena (e33)", 250),
                            .t("antenaMale", "Mesh nam (tay phải)", true), .t("antenaFemale", "Mesh nữ (tay trái)", true)]),

        MakePreset(id: "7", category: .aimlock, name: "Aimlock Body 90%", line: "Tâm khoá vào ngực / thân",
                   desc: "Gắn bone_Head phụ vào đốt sống ngực bone_Spine1 rồi phóng scale vùng thân, tâm khoá chặt vào Body. Không đụng xương chân.",
                   need: .uma, needLabel: "assetindexer", badges: [MakeBadge(text: "AIM THÂN 90%", style: .safe), MakeBadge(text: "UMA", style: .uma)],
                   tuneTitle: "Tinh chỉnh preset 7",
                   fields: [.n("bodyMaleScale", "Nam · scale thân", 1.555556), .n("bodyFemaleScale", "Nữ · scale thân", 1.5),
                            .n("bodyPosX", "Tọa độ ngực (position.x)", -0.0446), .n("bodyPosY", "Tọa độ ngực (position.y)", -0.0039),
                            .t("bodyMale", "Mesh nam", true), .t("bodyFemale", "Mesh nữ", true)]),

        MakePreset(id: "8", category: .aimlock, name: "Aimlock Cổ (Neck Lock)", line: "Tâm khoá vào yết hầu",
                   desc: "bone_Head phụ gắn tại bone_Spine1 với tọa độ cổ x = −0.244620, scale 1.5. Chân giữ nguyên. Khớp 100% từng byte file neck mẫu.",
                   need: .uma, needLabel: "assetindexer", badges: [MakeBadge(text: "NECK LOCK", style: .safe), MakeBadge(text: "UMA", style: .uma)],
                   tuneTitle: "Tinh chỉnh preset 8",
                   fields: [.n("neckPosX", "Tọa độ cổ (position.x)", -0.244620), .n("neckScale", "Scale vùng cổ", 1.5),
                            .t("neckMale", "Mesh nam", true), .t("neckFemale", "Mesh nữ", false)]),

        MakePreset(id: "10", category: .aimlock, name: "Aim Cằm Tap Shotgun / SMG", line: "Face lock — gom chùm đạn",
                   desc: "Đặt hitbox ngay dưới cằm (x = −0.31) và mở rộng 1.8×, tối ưu gom chùm đạn shotgun và sấy MP40/UMP ra headshot đỏ.",
                   need: .uma, needLabel: "assetindexer", badges: [MakeBadge(text: "FACE LOCK", style: .safe), MakeBadge(text: "UMA", style: .uma)],
                   tuneTitle: "Tinh chỉnh preset 10",
                   fields: [.n("facePosX", "Tọa độ cằm (position.x)", -0.31), .n("faceScale", "Scale vùng cằm/mặt", 1.8),
                            .t("faceMale", "Mesh nam", true), .t("faceFemale", "Mesh nữ", true)]),

        MakePreset(id: "11", category: .aimlock, name: "Aim Kín / Chống Tố Cáo", line: "Legit smooth aim",
                   desc: "Lệch nhẹ (x = −0.18) và hitbox vừa vặn 1.25×. Tâm bám mượt tự nhiên, khi bị spectate góc nhìn thứ nhất không giật cục hay lộ liễu.",
                   need: .uma, needLabel: "assetindexer", badges: [MakeBadge(text: "KÍN ĐÁO 100%", style: .safe), MakeBadge(text: "UMA", style: .uma)],
                   tuneTitle: "Tinh chỉnh preset 11",
                   fields: [.n("legitPosX", "Tọa độ ngực trên (position.x)", -0.18), .n("legitScale", "Scale nhẹ (tự nhiên)", 1.25),
                            .t("legitMale", "Mesh nam", true), .t("legitFemale", "Mesh nữ", true)]),

        MakePreset(id: "9", category: .magic, name: "Magic Bullet Siêu To", line: "Hitbox đầu giả ×3 phủ thân trên",
                   desc: "Nhân hitbox đầu giả lên 3 lần, phủ trọn nửa thân trên và khoảng không quanh người. Bắn lệch ra ngoài cạnh người vẫn tính trúng.",
                   need: .uma, needLabel: "assetindexer", badges: [MakeBadge(text: "SIÊU TO 3.0X", style: .magic), MakeBadge(text: "UMA", style: .uma)],
                   tuneTitle: "Tinh chỉnh preset 9",
                   fields: [.n("magicPosX", "Tọa độ tâm hitbox (position.x)", -0.2), .n("magicScale", "Scale hitbox khổng lồ", 3.0),
                            .t("magicMale", "Mesh nam", true), .t("magicFemale", "Mesh nữ", true)]),

        MakePreset(id: "12", category: .antena, name: "Combo: Antena + Aimlock Cổ", line: "Cột sóng + khoá yết hầu",
                   desc: "Gộp hai tính năng vào một file: cột sóng Antena định vị từ xa + tâm tự khoá vào yết hầu. Cả hai sửa in-place trong raw block.",
                   need: .uma, needLabel: "assetindexer", badges: [MakeBadge(text: "COMBO 2-IN-1", style: .antena), MakeBadge(text: "UMA", style: .uma)],
                   tuneTitle: "Tinh chỉnh preset 12",
                   fields: [.n("comboPosX", "Tọa độ cổ (position.x)", -0.244620), .n("comboScale", "Scale vùng cổ", 1.5),
                            .n("comboAntena", "Chiều cao Antena (e33)", 250),
                            .t("comboMale", "Mesh nam", true), .t("comboFemale", "Mesh nữ", true)]),

        MakePreset(id: "13", category: .antena, name: "Studio Aim Tự Do (Custom)", line: "Tự chọn độ cao, scale, antena",
                   desc: "Phòng thí nghiệm: nhập tọa độ độ cao bất kỳ, thu/phóng hitbox 1×–5×, kết hợp Antena hoặc kéo ngón chân (toeDrag). Xem trực tiếp ở khung mô phỏng.",
                   need: .uma, needLabel: "assetindexer", badges: [MakeBadge(text: "STUDIO PRO", style: .studio), MakeBadge(text: "UMA", style: .uma)],
                   tuneTitle: "Tinh chỉnh preset 13",
                   fields: [.n("custPosX", "Tọa độ Aim (thân −0.04 · cổ −0.24 · cằm −0.31 · đầu −0.38)", -0.244620),
                            .n("custScale", "Tỉ lệ Scale hitbox (1.0x – 5.0x)", 1.5),
                            .n("custAntenaHeight", "Chiều cao Antena (e33)", 250),
                            .t("custAntena", "Bật Antena (cột sóng định vị)", false), .t("custToe", "Bật kéo chân (toeDrag ×1.5)", false),
                            .t("custMale", "Mesh nam", true), .t("custFemale", "Mesh nữ", true)]),

        MakePreset(id: "14", category: .hitbox, name: "Aim Body 100%", line: "Hitbox đầu dời về ngực",
                   desc: "Dời tâm CapsuleCollider của bone_Head xuống ngực, bán kính ×1.68 và triệt tiêu 34 collider thân/tay/chân — mọi viên trúng người đều ăn hitbox đầu.",
                   need: .hitbox, needLabel: "cache_res", badges: [MakeBadge(text: "CHUẨN MẪU 100%", style: .model), MakeBadge(text: "CACHE_RES", style: .hitbox)],
                   tuneTitle: "Tinh chỉnh preset 14",
                   fields: [.n("hbMaleCenterX", "Nam · Tọa độ ngực (Center.x)", 0.124686), .n("hbMaleRadius", "Nam · Bán kính (Radius)", 0.099059),
                            .n("hbFemaleCenterX", "Nữ · Tọa độ ngực (Center.x)", 0.124096), .n("hbFemaleRadius", "Nữ · Bán kính (Radius)", 0.099154),
                            .t("hbMale", "Mesh nam (Male_DTSCollider)", true), .t("hbFemale", "Mesh nữ (Female_DTSCollider)", true),
                            .t("hbZeroOthers", "Triệt tiêu 34 hitbox thân/tay/chân", true)]),

        MakePreset(id: "15", category: .hitbox, name: "Aim Drag Headshot", line: "Kéo tâm — hitbox đầu ở cằm/cổ",
                   desc: "Dời tâm CapsuleCollider bone_Head xuống cằm/yết hầu, phình bán kính ×1.68. 35 collider cơ thể giữ nguyên — vuốt tâm lên vừa chớm qua ngực là ăn headshot.",
                   need: .hitbox, needLabel: "cache_res", badges: [MakeBadge(text: "CHUẨN MẪU 100%", style: .model), MakeBadge(text: "CACHE_RES", style: .hitbox)],
                   tuneTitle: "Tinh chỉnh preset 15",
                   fields: [.n("dragMaleCenterX", "Nam · Tọa độ cằm/cổ (Center.x)", 0.005245), .n("dragMaleRadius", "Nam · Bán kính (Radius)", 0.099059),
                            .n("dragFemaleCenterX", "Nữ · Tọa độ cằm/cổ (Center.x)", 0.005775), .n("dragFemaleRadius", "Nữ · Bán kính (Radius)", 0.099154),
                            .t("dragMale", "Mesh nam", true), .t("dragFemale", "Mesh nữ", true)]),

        MakePreset(id: "16", category: .hitbox, name: "Aimlock Cổ (cache_res)", line: "Hitbox cổ thon gọn (r = 0.075)",
                   desc: "Như Drag nhưng bán kính chỉ 0.075 (< 0.099): hitbox thon gọn ở yết hầu, đường đạn kín đáo tự nhiên, chống nghi ngờ khi bị theo dõi.",
                   need: .hitbox, needLabel: "cache_res", badges: [MakeBadge(text: "KÍN ĐÁO", style: .safe), MakeBadge(text: "CACHE_RES", style: .hitbox)],
                   tuneTitle: "Tinh chỉnh preset 16",
                   fields: [.n("neckCacheMaleCenterX", "Nam · Tọa độ yết hầu (Center.x)", 0.005245), .n("neckCacheMaleRadius", "Nam · Bán kính (nhỏ hơn drag 0.099)", 0.075),
                            .n("neckCacheFemaleCenterX", "Nữ · Tọa độ yết hầu (Center.x)", 0.005775), .n("neckCacheFemaleRadius", "Nữ · Bán kính (nhỏ hơn drag 0.099)", 0.0751),
                            .t("neckCacheMale", "Mesh nam", true), .t("neckCacheFemale", "Mesh nữ", true)]),

        MakePreset(id: "17", category: .hitbox, name: "Magic Bullet Khổng Lồ", line: "34 collider phình bán kính 0.8",
                   desc: "Phóng đồng loạt 34 CapsuleCollider lên Radius = Height = 0.8. Các khối cầu đan xen tạo thành một khối cầu tàng hình khổng lồ quanh người — bắn lệch tâm vẫn trúng.",
                   need: .hitbox, needLabel: "cache_res", badges: [MakeBadge(text: "HITBOX KHỔNG LỒ", style: .magic), MakeBadge(text: "CACHE_RES", style: .hitbox)],
                   tuneTitle: "Tinh chỉnh preset 17",
                   fields: [.n("magicCacheRadius", "Bán kính hitbox thân/chi (mẫu 0.8)", 0.8), .n("magicCacheHeight", "Chiều cao hitbox thân/chi (mẫu 0.8)", 0.8),
                            .t("magicCacheBody", "Phóng to 34 collider thân/tay/chân", true), .t("magicCacheHead", "Phóng to luôn hitbox đầu", false)]),

        MakePreset(id: "18", category: .hitbox, name: "Aim Chest", line: "Dịch xuống ngực, không phóng to",
                   desc: "Giữ nguyên bán kính như Drag (0.099), chỉ dịch tâm bone_Head xuống ngực trên. Bắn cổ/ngực dính headshot đỏ, không phóng to nên không lỗi dame.",
                   need: .hitbox, needLabel: "cache_res", badges: [MakeBadge(text: "CHUẨN MẪU 100%", style: .model), MakeBadge(text: "CACHE_RES", style: .hitbox)],
                   tuneTitle: "Tinh chỉnh preset 18",
                   fields: [.n("chestMaleCenterX", "Nam · Tọa độ ngực (Center.x)", 0.039245), .n("chestMaleRadius", "Nam · Bán kính (Radius)", 0.099059),
                            .n("chestFemaleCenterX", "Nữ · Tọa độ ngực (Center.x)", 0.039245), .n("chestFemaleRadius", "Nữ · Bán kính (Radius)", 0.099154),
                            .t("chestMale", "Mesh nam", true), .t("chestFemale", "Mesh nữ", true)])
    ]

    static func preset(_ id: String) -> MakePreset? { all.first { $0.id == id } }
}
