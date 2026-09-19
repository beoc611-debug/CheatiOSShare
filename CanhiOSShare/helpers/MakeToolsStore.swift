import SwiftUI

enum MakeGender: String {
    case male, female
}

enum MakeServerStatus {
    case checking, online, offline, noAccess
}

struct GameScannedFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let gameName: String
    let bundleID: String
    let size: Int64
    let hint: String
}

struct MakeBackup: Identifiable, Codable {
    var id: UUID = UUID()
    var fileName: String
    var gameName: String
    var bundleID: String
    var originalFullPath: String       // full path in container (UUID may change on reinstall)
    var relativePathInContainer: String // e.g. Documents/contentcache/...
    var hint: String
    var backupDate: Date
    var fileSize: Int
    var localFile: String              // UUID.bundle in MakeBackups dir
}

/// Trạng thái của tab "Tools Make": file đang mở, preset đang chọn, mọi giá trị tùy chỉnh.
/// Là singleton để chuyển tab không làm mất file/thông số.
final class MakeToolsStore: ObservableObject {
    static let shared = MakeToolsStore()

    private static let serverBase = "https://patches.cheatiosvip.net"

    // File
    @Published var fileName: String?
    @Published var fileSize = 0
    @Published var detection: MakeDetection?
    @Published var infoRows: [[String]] = []
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var loadError: String?
    @Published var loadWarning: String?
    @Published var uploadStatus: String?

    // Chọn preset
    @Published var selectedID = "12"
    @Published var gender: MakeGender = .male
    @Published var filter: MakeCategory?
    @Published var showCompatibleOnly: Bool = false

    // Giá trị tùy chỉnh (khoá giống id ô nhập của bản HTML)
    @Published var values: [String: Double] = [:]
    @Published var flags: [String: Bool] = [:]
    @Published var hexes: [String: String] = [:]

    // Scan game
    @Published var isScanning = false
    @Published var scannedFiles: [GameScannedFile] = []
    @Published var showScanResults = false

    // Nguồn từ game (set khi load từ scan)
    @Published var sourceGamePath: String?
    @Published var sourceGameBundleID: String?
    @Published var sourceGameName: String?
    @Published var sourceGameHint: String?

    // Patch vào game
    @Published var isPatchingGame = false
    @Published var patchGameResult: String?   // "ok" | "err:..." | nil

    // Kho backup
    @Published var showBackups = false

    // Server status
    @Published var serverStatus: MakeServerStatus = .checking

    // Kết quả
    @Published var isBusy = false
    @Published var result: MakeResult?
    @Published var resultStats: [[String]] = []
    @Published var resultError: String?

    private var orig: Bytes?
    private var bundle: UnityBundle?
    private var serverToken: String?
    private var serverResultData: Data?

    init() {
        resetAll()
    }

    // MARK: Giá trị mặc định

    func resetAll() {
        for p in MakeToolsCatalog.all { reset(p) }
    }

    func reset(_ p: MakePreset) {
        for f in p.fields {
            switch f.kind {
            case .number, .slider: values[f.id] = f.num
            case .toggle: flags[f.id] = f.flag
            case .color: hexes[f.id] = f.hex
            }
        }
    }

    // Đọc giá trị — `val` mô phỏng `parseFloat(...) || mặc định` của script gốc
    func val(_ id: String, _ d: Double) -> Double {
        let v = values[id] ?? d
        return (v == 0 || v.isNaN) ? d : v
    }
    func raw(_ id: String, _ d: Double) -> Double {
        let v = values[id] ?? d
        return v.isNaN ? d : v
    }
    func flag(_ id: String) -> Bool { flags[id] ?? false }
    func hex(_ id: String, _ d: String = "#FFFFFF") -> String { hexes[id] ?? d }

    func rgb(_ id: String, _ d: String) -> [Float] {
        let h = hex(id, d)
        guard let c = Color(hex: h) else { return [1, 1, 1] }
        let ui = UIColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Float(r), Float(g), Float(b)]
    }

    // MARK: Tương thích preset với file đang mở

    var kind: MakeBundleKind? { detection?.kind }
    var hasFile: Bool { orig != nil && bundle != nil }

    func isCompatible(_ p: MakePreset) -> Bool {
        guard let k = kind else { return false }
        return p.need == k
    }

    var selected: MakePreset {
        MakeToolsCatalog.preset(selectedID) ?? MakeToolsCatalog.all[0]
    }

    var canGenerate: Bool { hasFile && isCompatible(selected) && !isBusy }
    var canPatchGame: Bool { result != nil && sourceGamePath != nil && sourceGameBundleID != nil && !isBusy && !isPatchingGame }

    var visiblePresets: [MakePreset] {
        var pool: [MakePreset]
        if let f = filter {
            pool = MakeToolsCatalog.all.filter { $0.category == f }
        } else {
            pool = MakeToolsCatalog.all
        }
        if showCompatibleOnly {
            pool = pool.filter { isCompatible($0) }
        }
        return pool
    }

    // MARK: Nạp file

    func load(url: URL) {
        isLoading = true
        isUploading = false
        loadError = nil
        loadWarning = nil
        uploadStatus = nil
        result = nil
        resultError = nil
        serverToken = nil
        serverResultData = nil
        let name = url.lastPathComponent

        Task.detached(priority: .userInitiated) { [weak self] in
            let started = url.startAccessingSecurityScopedResource()
            defer { if started { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let bytes = Bytes(data)
                let b = try UnityBundle.parse(bytes)
                let det = MakeToolsEngine.detect(bytes, b)
                let nowHash = MakeToolsEngine.cdnHash(bytes)
                await MainActor.run {
                    self?.finishLoad(name: name, bytes: bytes, bundle: b, detection: det, nowHash: nowHash)
                }
                // Upload to server after local parse
                await self?.uploadToServer(data: data, fileName: name)
            } catch {
                let msg = error.localizedDescription
                await MainActor.run {
                    self?.failLoad(name: name, message: msg)
                }
            }
        }
    }

    private func uploadToServer(data: Data, fileName: String) async {
        await MainActor.run { isUploading = true; uploadStatus = "Đang tải lên server…" }
        defer { Task { @MainActor in self.isUploading = false } }
        do {
            guard let url = URL(string: MakeToolsStore.serverBase + "/api/make-tools/upload") else { return }
            var req = URLRequest(url: url, timeoutInterval: 120)
            req.httpMethod = "POST"
            let boundary = "Boundary-\(UUID().uuidString)"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            let keyCode = LicenseGateStore.storedKeyCode ?? ""
            var body = Data()
            // key field
            if !keyCode.isEmpty {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"key\"\r\n\r\n".data(using: .utf8)!)
                body.append(keyCode.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"bundle\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            req.httpBody = body
            let (respData, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                let errJSON = try? JSONSerialization.jsonObject(with: respData) as? [String: Any]
                let errCode = errJSON?["error"] as? String ?? ""
                let msg: String
                if errCode == "key_no_premium" {
                    msg = "Key không có quyền dùng Tools Make. Cần key Admin hoặc từ Seller Premium."
                } else {
                    msg = (errJSON?["message"] as? String) ?? (errCode.isEmpty ? "Lỗi server" : errCode)
                }
                await MainActor.run { self.uploadStatus = "Upload thất bại: \(msg)" }
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let token = json["token"] as? String {
                await MainActor.run {
                    self.serverToken = token
                    self.uploadStatus = "Đã tải lên server ✓"
                }
            }
        } catch {
            await MainActor.run { self.uploadStatus = "Upload lỗi: \(error.localizedDescription)" }
        }
    }

    private func failLoad(name: String, message: String) {
        orig = nil
        bundle = nil
        detection = nil
        infoRows = []
        fileName = name
        fileSize = 0
        loadError = message
        isLoading = false
    }

    private func finishLoad(name: String, bytes: Bytes, bundle b: UnityBundle, detection det: MakeDetection, nowHash: String) {
        orig = bytes
        bundle = b
        detection = det
        fileName = name
        fileSize = bytes.count
        isLoading = false

        if b.declared != bytes.count {
            loadWarning = "Trường size trong header (\(MakeToolsEngine.viNum(b.declared))) khác dung lượng thật (\(MakeToolsEngine.viNum(bytes.count))) — file có thể còn dữ liệu thừa ở đuôi. Tạo file mới sẽ sửa luôn."
        }
        if det.kind == nil {
            loadError = (det.why ?? "Không nhận ra loại bundle.") + " Tool này làm việc với assetindexer, shaders và cache_res."
        }

        let suffix: String = {
            guard let dot = name.firstIndex(of: ".") else { return "" }
            return String(name[name.index(after: dot)...])
        }()
        let isPristine = !suffix.isEmpty && suffix == nowHash
        let comp = b.blocks.filter { ($0.f & 0x3F) != 0 }.count

        var rows: [[String]] = []
        rows.append(["Tên", name])
        rows.append(["Dung lượng", "\(MakeToolsEngine.viNum(bytes.count)) byte"])
        if let build = det.build {
            let tag = det.guess ? " (phỏng đoán — dung lượng không khớp bản gốc đã biết)" : (isPristine ? " · bản gốc" : " · đã chỉnh sửa")
            rows.append(["Phiên bản", build + tag])
        } else if det.kind != nil {
            rows.append(["Phiên bản", "không rõ — dung lượng \(MakeToolsEngine.viNum(bytes.count)) byte không khớp Thường hay Max"])
        }
        rows.append(["Định dạng", "UnityFS fmt \(b.fmt) · \(b.rev)"])
        let compText = comp > 0 ? "có nén" : "uncompressed"
        rows.append(["Block", "\(b.blocks.count) · \(compText) · flags 0x\(hexString(b.flags))"])
        if let node = b.nodes.first { rows.append(["Node", "\(node.name) · \(MakeToolsEngine.viNum(node.size)) byte"]) }
        if let d = det.detail { rows.append(["Nhận diện", d]) }
        infoRows = rows

        // Tự chọn preset đầu tiên dùng được nếu preset hiện tại không hợp file
        if !isCompatible(selected), let first = MakeToolsCatalog.all.first(where: { isCompatible($0) }) {
            selectedID = first.id
        }
        // Auto-filter chỉ hiện preset dùng được ngay sau khi load
        filter = nil
        showCompatibleOnly = (det.kind != nil)
    }

    func clearFile() {
        orig = nil
        bundle = nil
        detection = nil
        infoRows = []
        fileName = nil
        fileSize = 0
        loadError = nil
        loadWarning = nil
        uploadStatus = nil
        result = nil
        resultError = nil
        serverToken = nil
        serverResultData = nil
        showCompatibleOnly = false
        sourceGamePath = nil
        sourceGameBundleID = nil
        sourceGameName = nil
        sourceGameHint = nil
        patchGameResult = nil
    }

    // MARK: Server connectivity

    func checkServer() {
        Task { await checkServerAsync() }
    }

    private func checkServerAsync() async {
        await MainActor.run { serverStatus = .checking }
        let keyCode = LicenseGateStore.storedKeyCode ?? ""
        var urlStr = MakeToolsStore.serverBase + "/api/make-tools/ping"
        if !keyCode.isEmpty, let enc = keyCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlStr += "?key=\(enc)"
        }
        guard let url = URL(string: urlStr) else {
            await MainActor.run { serverStatus = .offline }
            return
        }
        do {
            var req = URLRequest(url: url, timeoutInterval: 10)
            req.httpMethod = "GET"
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                await MainActor.run { serverStatus = .offline }
                return
            }
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let makeAccess = json["makeAccess"] as? Bool ?? false
            await MainActor.run { serverStatus = makeAccess ? .online : .noAccess }
        } catch {
            await MainActor.run { serverStatus = .offline }
        }
    }

    // MARK: Tạo file

    /// Dựng tham số cho engine từ các ô nhập — khớp trình xử lý nút "TẠO FILE" của bản HTML.
    func options(for id: String) -> MakeOptions {
        var o = MakeOptions()
        switch id {
        case "2":
            o.p2Fx = raw("fx", -0.23); o.p2Fz = raw("fz", -0.01)
            o.p2Mx = raw("mx", -0.3133402466773987); o.p2Scale = raw("sc", 1.5555556)
        case "5":
            o.toeScale = val("aimToeScale", 1.5); o.toeX = val("aimToeX", -0.3850825); o.toeY = val("aimToeY", -0.0746385)
            o.male = flag("aimMale"); o.female = flag("aimFemale")
        case "6":
            o.antenaHeight = val("antenaHeight", 250)
            o.male = flag("antenaMale"); o.female = flag("antenaFemale")
        case "7":
            o.maleScale = val("bodyMaleScale", 1.555556); o.femaleScale = val("bodyFemaleScale", 1.5)
            o.posX = val("bodyPosX", -0.0446); o.posY = val("bodyPosY", -0.0039)
            o.male = flag("bodyMale"); o.female = flag("bodyFemale")
        case "8":
            o.posX = val("neckPosX", -0.244620); o.scale = val("neckScale", 1.5)
            o.male = flag("neckMale"); o.female = flag("neckFemale")
        case "10":
            o.label = "Aim Cằm Tap Shotgun / SMG (Face Lock)"
            o.posX = val("facePosX", -0.31); o.scale = val("faceScale", 1.8)
            o.male = flag("faceMale"); o.female = flag("faceFemale")
        case "11":
            o.label = "Aim Kín / Chống Tố Cáo (Legit Smooth Aim)"
            o.posX = val("legitPosX", -0.18); o.scale = val("legitScale", 1.25)
            o.male = flag("legitMale"); o.female = flag("legitFemale")
        case "9":
            o.label = "Magic Bullet (Hitbox Siêu To Khổng Lồ)"
            o.posX = val("magicPosX", -0.2); o.scale = val("magicScale", 3.0)
            o.male = flag("magicMale"); o.female = flag("magicFemale")
        case "12":
            o.label = "Combo Siêu Cấp: Antena + Aimlock Cổ"
            o.posX = val("comboPosX", -0.244620); o.scale = val("comboScale", 1.5)
            o.antena = true; o.antenaHeight = val("comboAntena", 250)
            o.male = flag("comboMale"); o.female = flag("comboFemale")
        case "13":
            o.label = "Studio Tinh Chỉnh Aim Tự Do"
            o.posX = val("custPosX", -0.244620); o.scale = val("custScale", 1.5)
            o.antena = flag("custAntena"); o.antenaHeight = val("custAntenaHeight", 250)
            o.toeDrag = flag("custToe")
            o.male = flag("custMale"); o.female = flag("custFemale")
        case "14":
            o.maleCenterX = val("hbMaleCenterX", 0.124686); o.maleRadius = val("hbMaleRadius", 0.099059)
            o.femaleCenterX = val("hbFemaleCenterX", 0.124096); o.femaleRadius = val("hbFemaleRadius", 0.099154)
            o.male = flag("hbMale"); o.female = flag("hbFemale"); o.zeroOthers = flag("hbZeroOthers")
        case "15":
            o.maleCenterX = val("dragMaleCenterX", 0.005245); o.maleRadius = val("dragMaleRadius", 0.099059)
            o.femaleCenterX = val("dragFemaleCenterX", 0.005775); o.femaleRadius = val("dragFemaleRadius", 0.099154)
            o.male = flag("dragMale"); o.female = flag("dragFemale")
        case "16":
            o.maleCenterX = val("neckCacheMaleCenterX", 0.005245); o.maleRadius = val("neckCacheMaleRadius", 0.075)
            o.femaleCenterX = val("neckCacheFemaleCenterX", 0.005775); o.femaleRadius = val("neckCacheFemaleRadius", 0.0751)
            o.male = flag("neckCacheMale"); o.female = flag("neckCacheFemale")
        case "17":
            o.colRadius = val("magicCacheRadius", 0.8); o.colHeight = val("magicCacheHeight", 0.8)
            o.bodyOn = flag("magicCacheBody"); o.headOn = flag("magicCacheHead")
        case "18":
            o.maleCenterX = val("chestMaleCenterX", -0.030); o.maleRadius = val("chestMaleRadius", 0.099059)
            o.femaleCenterX = val("chestFemaleCenterX", -0.032); o.femaleRadius = val("chestFemaleRadius", 0.099154)
            o.male = flag("chestMale"); o.female = flag("chestFemale")
        case "3":
            o.xrayRGB = rgb("tXray", "#111111"); o.lineRGB = rgb("tLine", "#FFFFFF"); o.dimRGB = rgb("tDim", "#111111")
            o.width = Float(raw("rWidth", 4)); o.alpha = Float(raw("rAlpha", 1))
        case "4":
            o.tintRGB = rgb("tTint", "#00FFFF"); o.rimRGB = rgb("tRim", "#00FFFF"); o.scanRGB = rgb("tScan", "#000000")
            o.tintA = Float(raw("rTintA", 1)); o.rimA = Float(raw("rRimA", 1)); o.scanA = Float(raw("rScanA", 1))
            o.xrayOn = flag("kXray"); o.lineOn = flag("kLine"); o.glitchOn = flag("kGlitch")
        default:
            break
        }
        return o
    }

    func generate() {
        guard canGenerate else { return }
        let id = selectedID
        if id == "3" || id == "4" {
            for f in selected.fields where f.kind == .color {
                if Color(hex: hex(f.id, f.hex)) == nil {
                    resultError = "Mã màu \"\(f.label)\" không hợp lệ (cần dạng #RRGGBB)."
                    result = nil
                    return
                }
            }
        }
        guard let token = serverToken else {
            switch serverStatus {
            case .offline: resultError = "Mất kết nối server. Kiểm tra mạng và thử lại."
            case .noAccess: resultError = "Key không có quyền dùng Tools Make. Cần key Admin hoặc từ Seller Premium."
            default: resultError = "File chưa được upload lên server. Hãy thử chọn lại file."
            }
            return
        }

        isBusy = true
        result = nil
        resultError = nil
        serverResultData = nil

        let opt = options(for: id)
        Task { [weak self] in await self?.generateOnServer(token: token, presetId: id, options: opt) }
    }

    private func generateOnServer(token: String, presetId: String, options opt: MakeOptions) async {
        do {
            // Build JSON options from opt struct
            let body: [String: Any] = [
                "token": token, "presetId": Int(presetId) ?? 1,
                "options": [
                    "male": opt.male, "female": opt.female,
                    "posX": opt.posX, "posY": opt.posY, "posZ": opt.posZ,
                    "rotY": opt.rotY, "scale": opt.scale,
                    "maleScale": opt.maleScale, "femaleScale": opt.femaleScale,
                    "toeScale": opt.toeScale, "toeX": opt.toeX, "toeY": opt.toeY,
                    "p2Mx": opt.p2Mx, "p2Fx": opt.p2Fx, "p2Fz": opt.p2Fz, "p2Scale": opt.p2Scale,
                    "antena": opt.antena, "antenaHeight": opt.antenaHeight,
                    "toeDrag": opt.toeDrag,
                    "maleCenterX": opt.maleCenterX, "maleRadius": opt.maleRadius,
                    "femaleCenterX": opt.femaleCenterX, "femaleRadius": opt.femaleRadius,
                    "zeroOthers": opt.zeroOthers,
                    "colRadius": opt.colRadius, "colHeight": opt.colHeight,
                    "bodyOn": opt.bodyOn, "headOn": opt.headOn,
                    "width": opt.width, "alpha": opt.alpha,
                    "xrayOn": opt.xrayOn, "lineOn": opt.lineOn, "glitchOn": opt.glitchOn,
                    "xrayRGB": opt.xrayRGB, "lineRGB": opt.lineRGB, "dimRGB": opt.dimRGB,
                    "tintRGB": opt.tintRGB, "rimRGB": opt.rimRGB, "scanRGB": opt.scanRGB,
                    "tintA": opt.tintA, "rimA": opt.rimA, "scanA": opt.scanA,
                    "label": opt.label
                ]
            ]
            guard let genURL = URL(string: MakeToolsStore.serverBase + "/api/make-tools/generate") else { throw URLError(.badURL) }
            var genReq = URLRequest(url: genURL, timeoutInterval: 180)
            genReq.httpMethod = "POST"
            genReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            genReq.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (genData, genResp) = try await URLSession.shared.data(for: genReq)
            if let http = genResp as? HTTPURLResponse, http.statusCode != 200 {
                let msg = (try? JSONSerialization.jsonObject(with: genData) as? [String: Any])?["error"] as? String ?? "Lỗi server \(http.statusCode)"
                await MainActor.run { self.resultError = msg; self.isBusy = false }
                return
            }
            guard let genJSON = try? JSONSerialization.jsonObject(with: genData) as? [String: Any] else {
                await MainActor.run { self.resultError = "Phản hồi server không hợp lệ."; self.isBusy = false }
                return
            }
            let note = genJSON["note"] as? String ?? "Xong!"
            let cols = genJSON["cols"] as? [String] ?? []
            let rows = (genJSON["rows"] as? [[Any]] ?? []).map { $0.map { "\($0)" } }

            // Download result file
            guard let dlURL = URL(string: MakeToolsStore.serverBase + "/api/make-tools/download/\(token)") else { throw URLError(.badURL) }
            let (fileData, dlResp) = try await URLSession.shared.data(from: dlURL)
            if let http = dlResp as? HTTPURLResponse, http.statusCode != 200 {
                await MainActor.run { self.resultError = "Không tải được file kết quả."; self.isBusy = false }
                return
            }
            let outBytes = Bytes(fileData)
            let res = MakeResult(out: outBytes, note: note, cols: cols, rows: rows)
            let origBytes = self.orig
            var changed = 0
            let origCount = origBytes?.count ?? 0
            if let origBytes = origBytes, outBytes.count == origCount {
                for i in 0..<origCount where origBytes[i] != outBytes[i] { changed += 1 }
            }
            let diff = outBytes.count - origCount
            var sizeText = MakeToolsEngine.viNum(outBytes.count) + " byte "
            sizeText += (origCount > 0 && outBytes.count == origCount) ? "— khớp file nguồn" : ("— khác nguồn \(diff > 0 ? "+" : "")\(diff)")
            var stats: [[String]] = [["Dung lượng", sizeText], ["Nguồn", "Server ✓"]]
            if origCount > 0 && outBytes.count == origCount { stats.append(["Số byte đổi", MakeToolsEngine.viNum(changed)]) }
            await MainActor.run {
                self.serverResultData = fileData
                self.result = res
                self.resultStats = stats
                self.isBusy = false
            }
        } catch {
            let msg = error.localizedDescription
            await MainActor.run { self.resultError = "Server error: \(msg)"; self.isBusy = false }
        }
    }

    /// Ghi file đã sửa ra thư mục tạm (giữ nguyên tên gốc) để chia sẻ / lưu.
    func writeResultFile() -> URL? {
        guard let res = result, let name = fileName else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try Data(res.out).write(to: url, options: .atomic)
            return url
        } catch {
            resultError = "Không ghi được file: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: Kéo trên hình để đổi vị trí hitbox

    /// (khoá nam, khoá nữ, hệ toạ độ: true = UMA position.x, false = cache_res Center.x)
    static let dragKeys: [String: (String, String, Bool)] = [
        "2": ("mx", "fx", true), "5": ("aimToeX", "aimToeX", true), "7": ("bodyPosX", "bodyPosX", true),
        "8": ("neckPosX", "neckPosX", true), "9": ("magicPosX", "magicPosX", true), "10": ("facePosX", "facePosX", true),
        "11": ("legitPosX", "legitPosX", true), "12": ("comboPosX", "comboPosX", true), "13": ("custPosX", "custPosX", true),
        "14": ("hbMaleCenterX", "hbFemaleCenterX", false), "15": ("dragMaleCenterX", "dragFemaleCenterX", false),
        "16": ("neckCacheMaleCenterX", "neckCacheFemaleCenterX", false), "18": ("chestMaleCenterX", "chestFemaleCenterX", false)
    ]

    var isDraggable: Bool { MakeToolsStore.dragKeys[selectedID] != nil }

    // MARK: Dò file từ game

    func scanGameFiles() {
        guard !isScanning else { return }
        isScanning = true
        scannedFiles = []
        Task.detached(priority: .userInitiated) { [weak self] in
            let targets: [(String, String)] = [
                ("com.dts.freefireth", "Free Fire"),
                ("com.dts.freefiremax", "Free Fire Max")
            ]
            var found: [GameScannedFile] = []
            let fm = FileManager.default
            for (bid, gameName) in targets {
                guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bid) else { continue }
                let searchDirs = [
                    containerPath + "/Documents/contentcache/Compulsory/ios/gameassetbundles",
                    containerPath + "/Documents/contentcache/Compulsory/ios/gameassetbundles/avatar",
                    containerPath + "/Documents/contentcache/Optional/ios/gameassetbundles",
                    containerPath + "/Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles",
                ]
                for dir in searchDirs {
                    guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
                    for entry in entries {
                        let fullPath = dir + "/" + entry
                        var isDir = ObjCBool(false)
                        guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue else { continue }
                        let lower = entry.lowercased()
                        let hint: String
                        if lower.hasPrefix("cache_res") { hint = "Hitbox" }
                        else if lower.hasPrefix("assetindexer") { hint = "UMA / Aim" }
                        else if lower.hasPrefix("shaders") || lower.contains("_shader") { hint = "Shaders" }
                        else { continue }
                        let attrs = try? fm.attributesOfItem(atPath: fullPath)
                        let size = (attrs?[.size] as? Int64) ?? 0
                        found.append(GameScannedFile(name: entry, path: fullPath, gameName: gameName, bundleID: bid, size: size, hint: hint))
                    }
                }
            }
            await MainActor.run {
                self?.scannedFiles = found
                self?.isScanning = false
                self?.showScanResults = true
            }
        }
    }

    // MARK: Patch vào game

    func patchGameFile() {
        guard let res = result, let gamePath = sourceGamePath, let bid = sourceGameBundleID else { return }
        isPatchingGame = true
        patchGameResult = nil
        let data = serverResultData ?? Data(res.out)
        Task.detached(priority: .userInitiated) { [weak self] in
            // Re-resolve để làm mới sandbox extension token
            guard ContainerStore.resolveAppContainerPath(bundleID: bid) != nil else {
                await MainActor.run {
                    self?.patchGameResult = "err:Không tìm được container game. Đảm bảo game đã cài."
                    self?.isPatchingGame = false
                }
                return
            }
            do {
                try data.write(to: URL(fileURLWithPath: gamePath), options: .atomic)
                await MainActor.run { self?.patchGameResult = "ok"; self?.isPatchingGame = false }
            } catch {
                await MainActor.run {
                    self?.patchGameResult = "err:\(error.localizedDescription)"
                    self?.isPatchingGame = false
                }
            }
        }
    }

    // MARK: Backup file gốc

    static var backupDir: URL {
        (try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true))?
            .appendingPathComponent("MakeBackups", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MakeBackups")
    }

    private static func relPath(from fullPath: String, bundleID: String) -> String {
        // Extract relative path from container root.
        // Full path: /var/mobile/Containers/Data/Application/<UUID>/Documents/...
        // We look for /Documents/, /Library/, etc.
        for prefix in ["/Documents/", "/Library/", "/tmp/"] {
            if let r = fullPath.range(of: prefix) {
                return String(prefix.dropFirst()) + String(fullPath[r.upperBound...])
            }
        }
        return (fullPath as NSString).lastPathComponent
    }

    func saveBackupIfNew(data: Data, file: GameScannedFile) {
        var index = loadBackupIndex()
        // Skip if we already have a backup of this exact file (same path + size)
        let alreadyBacked = index.contains { $0.originalFullPath == file.path && $0.fileSize == Int(file.size) }
        guard !alreadyBacked else { return }

        let dir = MakeToolsStore.backupDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let backupID = UUID()
        let localFile = backupID.uuidString + ".bundle"
        guard (try? data.write(to: dir.appendingPathComponent(localFile))) != nil else { return }

        let backup = MakeBackup(
            id: backupID,
            fileName: file.name,
            gameName: file.gameName,
            bundleID: file.bundleID,
            originalFullPath: file.path,
            relativePathInContainer: MakeToolsStore.relPath(from: file.path, bundleID: file.bundleID),
            hint: file.hint,
            backupDate: Date(),
            fileSize: Int(file.size),
            localFile: localFile
        )
        index.insert(backup, at: 0)
        if index.count > 30 { index = Array(index.prefix(30)) }
        if let encoded = try? JSONEncoder().encode(index) {
            try? encoded.write(to: dir.appendingPathComponent("index.json"))
        }
    }

    func loadBackupIndex() -> [MakeBackup] {
        let url = MakeToolsStore.backupDir.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([MakeBackup].self, from: data) else { return [] }
        return list
    }

    func deleteBackup(_ backup: MakeBackup) {
        let dir = MakeToolsStore.backupDir
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(backup.localFile))
        var index = loadBackupIndex()
        index.removeAll { $0.id == backup.id }
        if let encoded = try? JSONEncoder().encode(index) {
            try? encoded.write(to: dir.appendingPathComponent("index.json"))
        }
    }

    func restoreBackup(_ backup: MakeBackup, completion: @escaping (Bool, String) -> Void) {
        let localURL = MakeToolsStore.backupDir.appendingPathComponent(backup.localFile)
        guard let data = try? Data(contentsOf: localURL) else {
            completion(false, "Không đọc được file backup."); return
        }
        Task.detached(priority: .userInitiated) {
            // Try direct path first, fallback to re-resolve + relative path
            var targetPath = backup.originalFullPath
            if !FileManager.default.fileExists(atPath: (backup.originalFullPath as NSString).deletingLastPathComponent) {
                // Container UUID may have changed — re-resolve
                if let newContainer = ContainerStore.resolveAppContainerPath(bundleID: backup.bundleID) {
                    targetPath = (newContainer as NSString).appendingPathComponent(backup.relativePathInContainer)
                } else {
                    await MainActor.run { completion(false, "Không tìm được container game.") }
                    return
                }
            } else {
                _ = ContainerStore.resolveAppContainerPath(bundleID: backup.bundleID)
            }
            do {
                try data.write(to: URL(fileURLWithPath: targetPath), options: .atomic)
                await MainActor.run { completion(true, "Đã khôi phục \(backup.fileName)") }
            } catch {
                await MainActor.run { completion(false, error.localizedDescription) }
            }
        }
    }

    func loadFromScanned(_ file: GameScannedFile) {
        showScanResults = false
        isLoading = true
        isUploading = false
        loadError = nil
        loadWarning = nil
        uploadStatus = nil
        result = nil
        resultError = nil
        serverToken = nil
        serverResultData = nil
        patchGameResult = nil
        sourceGamePath = file.path
        sourceGameBundleID = file.bundleID
        sourceGameName = file.gameName
        sourceGameHint = file.hint
        let name = file.name
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: file.path))
                // Auto-backup file gốc nếu chưa có
                self?.saveBackupIfNew(data: data, file: file)
                let bytes = Bytes(data)
                let b = try UnityBundle.parse(bytes)
                let det = MakeToolsEngine.detect(bytes, b)
                let nowHash = MakeToolsEngine.cdnHash(bytes)
                await MainActor.run { self?.finishLoad(name: name, bytes: bytes, bundle: b, detection: det, nowHash: nowHash) }
                await self?.uploadToServer(data: data, fileName: name)
            } catch {
                let msg = error.localizedDescription
                await MainActor.run { self?.failLoad(name: name, message: msg) }
            }
        }
    }

    /// `y` là toạ độ dọc trong không gian của hình (viewBox).
    func dragTo(y: Double) {
        guard let d = MakeToolsStore.dragKeys[selectedID] else { return }
        var x: Double
        if d.2 {
            x = (y - 190) / 384
            x = Swift.max(-0.5, Swift.min(0.15, x))
        } else {
            x = (y - 95) / 628 + 0.005245
            x = Swift.max(-0.03, Swift.min(0.2, x))
        }
        let key = gender == .male ? d.0 : d.1
        values[key] = (x * 1_000_000).rounded() / 1_000_000
    }
}
