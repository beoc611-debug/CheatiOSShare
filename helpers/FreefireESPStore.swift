import Foundation
import UIKit
import SwiftUI

struct PatchLogEntry: Identifiable {
    enum Level { case info, ok, warn, err }
    let id = UUID()
    let time: String
    let level: Level
    let text: String
}

// Manages Free Fire ESP state by reading/writing a config file in the game's
// Documents/ folder. The game reads the same file every ~1 second via the
// patched ESPLogic (replacing the old in-game 3-finger menu).
//
// Config file format (esp_cfg, 60 bytes):
//   bytes 0-3  : int32 LE — main state bits (bits 0-23 only, no thickness)
//   bytes 4-7  : int32 LE — aux state bits
//   bytes 8-10 : (reserved/unused)
//   bytes 11-13: thickness raw (line, box, name) — 0-97, px = 0.5 + raw * 0.2
//   bytes 14-16: line color (R, G, B) 0-255
//   bytes 17-19: box color (R, G, B)
//   bytes 20-22: health color (R, G, B)
//   bytes 23-25: name color (R, G, B)
//   bytes 26-28: dist color (R, G, B)
//   bytes 29-31: count color (R, G, B)

@MainActor
final class FreefireESPStore: ObservableObject {

    // MARK: - Bit constants
    private let bitEspMaster:       Int32 = 1
    private let bitEspBox:          Int32 = 2
    private let bitEspTracer:       Int32 = 4
    private let bitEspHealth:       Int32 = 8
    private let bitEspName:         Int32 = 16
    private let bitEspDistance:     Int32 = 32
    private let bitStateInitialized: Int32 = 128
    private let bitAimEnabled:      Int32 = 32768
    private let bitNoRecoil:        Int32 = 262144
    private let bitAimFov:          Int32 = 4194304
    private let bitAimFovHide:      Int32 = 8388608
    private let bitEspCount:        Int32 = 256
    private let bitEspColorEnabled: Int32 = 512
    private let bitEspSkeleton:     Int32 = 1024
    private let aimModeShift: Int32 = 16
    private let headRateShift: Int32 = 19
    private let auxFovRadiusShift: Int32 = 4
    private let auxSilentFovShift: Int32 = 12

    private let bitAuxFastParachute: Int32 = 1
    private let bitAuxSpeedRunning:  Int32 = 2
    private let bitAuxFakeDamage:    Int32 = 8
    private let bitAuxWideCamera:    Int32 = 16

    // MARK: - Game variant selector
    enum FFVariant: String, CaseIterable, Identifiable {
        case freefire    = "Free Fire"
        case freefireMax = "Free Fire MAX"
        var id: String { rawValue }
    }

    // MARK: - Known bundle IDs
    static let knownBundleIDs: [String] = [
        "com.dts.freefireth",
        "com.garena.game.kgvn",
        "com.garena.game.kgsg",
        "com.garena.game.kgtw",
        "com.garena.game.kgth",
        "com.garena.game.kgid",
        "com.garena.game.battleground"
    ]
    static let knownMAXBundleIDs: [String] = [
        "com.garena.game.fbrgvn",
        "com.garena.game.fbrgsg",
        "com.garena.game.fbrgtw",
        "com.garena.game.fbrgth",
        "com.garena.game.fbrgid",
        "com.garena.game.fbrgus",
        "com.dts.freefiremax"
    ]

    // MARK: - Published state (ESP tab)
    @Published var enableESP    = true
    @Published var playerBox    = true
    @Published var topTracer    = true
    @Published var healthBar    = true
    @Published var playerName   = true
    @Published var distance     = true
    @Published var espCount      = true
    @Published var espColorEnabled = false
    @Published var showSkeleton  = true

    // ESP Colors (full RGB — stored as bytes 14-31 in config)
    @Published var lineColor:   Color = Color(red: 1.00, green: 0.10, blue: 0.10)
    @Published var boxColor:    Color = Color(red: 1.00, green: 0.10, blue: 0.10)
    @Published var healthColor: Color = Color(red: 0.10, green: 0.95, blue: 0.10)
    @Published var nameColor:   Color = Color(red: 1.00, green: 1.00, blue: 0.10)
    @Published var distColor:     Color = Color(red: 1.00, green: 1.00, blue: 1.00)
    @Published var countColor:    Color = Color(red: 1.00, green: 0.10, blue: 0.10)
    @Published var skeletonColor: Color = Color(red: 1.00, green: 1.00, blue: 1.00)
    @Published var fovColor:      Color = Color(red: 1.00, green: 1.00, blue: 1.00)

    // Thickness raw (0-97 → px = 0.5 + raw * 0.2, max 20.0 px at raw=97)
    // Health bar width auto-follows boxThicknessRaw (no separate slider)
    @Published var lineThicknessRaw:  Int32 = 5   // → 1.5 px
    @Published var boxThicknessRaw:   Int32 = 5   // → 1.5 px
    @Published var nameThicknessRaw:  Int32 = 5   // → 1.5 px
    @Published var skelThicknessRaw:  Int32 = 5   // → 1.5 px

    // UI-only: which element is being edited in the color picker
    @Published var selectedEspElement: Int = 0

    // Server-driven toggle states (keyed by UIConfigItem.id from server)
    @Published var serverToggles: [String: Bool] = [:]

    func boolValue(for id: String) -> Bool {
        switch id {
        case "enableESP":      return enableESP
        case "playerBox":      return playerBox
        case "topTracer":      return topTracer
        case "healthBar":      return healthBar
        case "playerName":     return playerName
        case "distance":       return distance
        case "showSkeleton":   return showSkeleton
        case "espCount":       return espCount
        case "espColorEnabled":return espColorEnabled
        case "silentAim":      return silentAim
        case "noRecoil":       return noRecoil
        case "aimFov":         return aimFov
        case "aimFovHide":     return aimFovHide
        case "fastParachute":  return fastParachute
        case "speedRunning":   return speedRunning
        case "fakeDamage":     return fakeDamage
        case "wideCamera":     return wideCamera
        default:               return serverToggles[id] ?? false
        }
    }

    func toggleById(_ id: String) {
        switch id {
        case "enableESP":      toggle(\.enableESP)
        case "playerBox":      toggle(\.playerBox)
        case "topTracer":      toggle(\.topTracer)
        case "healthBar":      toggle(\.healthBar)
        case "playerName":     toggle(\.playerName)
        case "distance":       toggle(\.distance)
        case "showSkeleton":   toggle(\.showSkeleton)
        case "espCount":       toggle(\.espCount)
        case "espColorEnabled":toggle(\.espColorEnabled)
        case "silentAim":      toggle(\.silentAim)
        case "noRecoil":       toggle(\.noRecoil)
        case "aimFov":         toggle(\.aimFov)
        case "aimFovHide":     toggle(\.aimFovHide)
        case "fastParachute":  toggle(\.fastParachute)
        case "speedRunning":   toggle(\.speedRunning)
        case "fakeDamage":     toggle(\.fakeDamage)
        case "wideCamera":     toggle(\.wideCamera)
        default:               serverToggles[id] = !(serverToggles[id] ?? false)
        }
    }

    // AIM tab
    @Published var silentAim    = false
    @Published var silentFov: Int32 = 200
    @Published var noRecoil     = false
    @Published var aimFov       = false
    @Published var aimFovHide   = false
    @Published var fovRadius: Int32 = 100
    @Published var aimMode: Int32 = 1
    @Published var headRate: Int32 = 3

    // SETTINGS tab
    @Published var fastParachute = false
    @Published var speedRunning  = false
    @Published var fakeDamage    = false
    @Published var wideCamera    = false
    @Published var wideCameraFov: Int32 = 88

    // MARK: - Status
    @Published var selectedVariant: FFVariant = .freefire
    @Published var detectedBundleID: String?
    @Published var detectedMAXBundleID: String?
    @Published var isPatchInstalled    = false
    @Published var isPatchInstalledMAX = false
    @Published var isPatching        = false
    @Published var patchResult: PatchResult?
    @Published var patchLog: [PatchLogEntry] = []
    var storedFeatureToken: String = ""

    enum PatchResult: Identifiable, Equatable {
        case success
        case failure(String)
        var id: String {
            switch self { case .success: return "ok"; case .failure(let m): return m }
        }
    }

    // MARK: - Init
    init() {
        refresh()
        flushState()
    }

    // MARK: - Container resolution

    private func resolvedContainer(for variant: FFVariant) -> (bundleID: String, path: String)? {
        let ids = variant == .freefire ? Self.knownBundleIDs : Self.knownMAXBundleIDs
        for id in ids {
            if let path = ContainerStore.resolveAppContainerPath(bundleID: id) {
                return (id, path)
            }
        }
        return nil
    }

    private var resolvedContainer: (bundleID: String, path: String)? {
        resolvedContainer(for: selectedVariant)
    }

    private func documentsPath(in container: String) -> String {
        (container as NSString).appendingPathComponent("Documents")
    }

    private func configFilePath(in container: String) -> String {
        let dir = (documentsPath(in: container) as NSString)
            .appendingPathComponent("contentcache/Compulsory/ios/gameassetbundles/ingame")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return (dir as NSString).appendingPathComponent(".pdata")
    }

    func checkESPStatus() -> String {
        guard let (bundleID, container) = resolvedContainer else {
            return "❓ Không tìm thấy game container"
        }
        // Unity iOS uses "unity.{bundleID}.plist" in some versions, "{bundleID}.plist" in others
        let paths = [
            "\(container)/Library/Preferences/unity.\(bundleID).plist",
            "\(container)/Library/Preferences/\(bundleID).plist",
            "\(container)/Library/Preferences/unity.\(bundleID).player.plist",
        ]
        guard let plistPath = paths.first(where: { FileManager.default.fileExists(atPath: $0) }),
              let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)) else {
            return "❓ Không tìm thấy PlayerPrefs plist"
        }
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil) as? [String: Any] else {
            return "❓ Không parse được PlayerPrefs"
        }
        var espTv: Float = -1
        if let v = plist["esp_tv"] as? Float { espTv = v }
        else if let v = plist["esp_tv"] as? Double { espTv = Float(v) }
        else if let v = plist["esp_tv"] as? Int { espTv = Float(v) }
        if espTv < 0 { return "❓ esp_tv chưa set (mở game trước)" }
        var phashStr = ""
        if let v = plist["esp_phash"] as? Float {
            phashStr = " | path_hash=\(v.bitPattern)"
        } else if let v = plist["esp_phash"] as? Double {
            phashStr = " | path_hash=\(Float(v).bitPattern)"
        }
        return espTv >= 0.5
            ? "✅ ESP: BẬT\(phashStr)"
            : "❌ ESP: TẮT\(phashStr)"
    }

    private func patchBytesPath(in container: String) -> String {
        (documentsPath(in: container) as NSString)
            .appendingPathComponent("Assembly-CSharp-patch.bytes")
    }

    private func localConfigPath(in container: String) -> String {
        (documentsPath(in: container) as NSString)
            .appendingPathComponent("localConfig.json")
    }

    // MARK: - Public interface

    func refresh() {
        if let (bundleID, container) = resolvedContainer(for: .freefire) {
            detectedBundleID = bundleID
            isPatchInstalled = FileManager.default.fileExists(atPath: patchBytesPath(in: container))
        } else {
            detectedBundleID = nil
            isPatchInstalled = false
        }
        if let (bundleID, container) = resolvedContainer(for: .freefireMax) {
            detectedMAXBundleID = bundleID
            isPatchInstalledMAX = FileManager.default.fileExists(atPath: patchBytesPath(in: container))
        } else {
            detectedMAXBundleID = nil
            isPatchInstalledMAX = false
        }
        if let (_, container) = resolvedContainer {
            readState(from: container)
        }
    }

    func selectVariant(_ variant: FFVariant) {
        selectedVariant = variant
        if let (_, container) = resolvedContainer {
            readState(from: container)
            flushState()
        }
    }

    func toggle(_ keyPath: ReferenceWritableKeyPath<FreefireESPStore, Bool>) {
        self[keyPath: keyPath].toggle()
        flushState()
    }

    func flushStatePublic() { flushState() }

    func clearLog() { patchLog = [] }

    private func addLog(_ text: String, level: PatchLogEntry.Level = .info) {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        patchLog.append(PatchLogEntry(time: f.string(from: Date()), level: level, text: text))
    }

    func set(_ keyPath: ReferenceWritableKeyPath<FreefireESPStore, Bool>, to value: Bool) {
        self[keyPath: keyPath] = value
        flushState()
    }

    func setAimMode(_ mode: Int32) {
        aimMode = mode
        flushState()
    }

    func setHeadRate(_ rate: Int32) {
        headRate = rate
        flushState()
    }

    func setSilentFov(_ radius: Int32) {
        silentFov = max(50, min(500, radius))
        flushState()
    }

    func setFovRadius(_ radius: Int32) {
        fovRadius = max(30, min(500, radius))
        flushState()
    }

    func setWideCameraFov(_ fov: Int32) {
        wideCameraFov = max(60, min(120, fov))
        flushState()
    }

    func doubleValue(for id: String) -> Double {
        switch id {
        case "wideCameraFov": return Double(wideCameraFov)
        case "silentFov":     return Double(silentFov)
        case "fovRadius":     return Double(fovRadius)
        default:              return 0
        }
    }

    func setDouble(for id: String, _ value: Double) {
        switch id {
        case "wideCameraFov": setWideCameraFov(Int32(value))
        case "silentFov":     setSilentFov(Int32(value))
        case "fovRadius":     setFovRadius(Int32(value))
        default:              break
        }
    }

    func removePatches() {
        guard let (_, container) = resolvedContainer else { return }
        let fm = FileManager.default
        try? fm.removeItem(atPath: patchBytesPath(in: container))
        try? fm.removeItem(atPath: configFilePath(in: container))
        try? fm.removeItem(atPath: localConfigPath(in: container))
        let docsPath = documentsPath(in: container)
        try? fm.removeItem(atPath: (docsPath as NSString).appendingPathComponent("token.json"))
        storedFeatureToken = ""
        tokenRefreshTask?.cancel()
        tokenRefreshTask = nil
        refresh()
    }

    private func openGame() {
        let schemes: [String: String] = [
            "com.dts.freefireth":            "freefireth://",
            "com.dts.freefiremax":           "freefiremax://",
            "com.garena.game.kgvn":          "garena://",
            "com.garena.game.kgsg":          "garena://",
            "com.garena.game.kgtw":          "garena://",
            "com.garena.game.kgth":          "garena://",
            "com.garena.game.kgid":          "garena://",
            "com.garena.game.battleground":  "garena://",
            "com.garena.game.fbrgvn":        "garena://",
            "com.garena.game.fbrgsg":        "garena://",
            "com.garena.game.fbrgtw":        "garena://",
            "com.garena.game.fbrgth":        "garena://",
            "com.garena.game.fbrgid":        "garena://",
            "com.garena.game.fbrgus":        "garena://"
        ]
        let bundleID = selectedVariant == .freefire ? detectedBundleID : detectedMAXBundleID
        guard let bid = bundleID,
              let scheme = schemes[bid],
              let url = URL(string: scheme) else { return }
        UIApplication.shared.open(url)
    }

    func patchGame() {
        guard !isPatching else { return }
        isPatching = true
        patchResult = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let result: PatchResult
            do {
                result = try await self.performPatch()
            } catch {
                result = .failure(error.localizedDescription)
            }

            await MainActor.run {
                self.isPatching = false
                self.patchResult = result
                if case .success = result {
                    self.refresh()
                    self.flushState()
                    self.openGame()
                }
            }
        }
    }

    // MARK: - Color helpers

    private func colorToBytes(_ color: Color) -> (UInt8, UInt8, UInt8) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (
            UInt8(max(0, min(255, Int(r * 255 + 0.5)))),
            UInt8(max(0, min(255, Int(g * 255 + 0.5)))),
            UInt8(max(0, min(255, Int(b * 255 + 0.5))))
        )
    }

    private func bytesToColor(r: UInt8, g: UInt8, b: UInt8) -> Color {
        Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
    }

    // MARK: - Private

    private func readState(from container: String) {
        let path = configFilePath(in: container)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              data.count >= 4 else { return }

        var mainBits: Int32 = 0
        _ = withUnsafeMutableBytes(of: &mainBits) { ptr in
            data.copyBytes(to: ptr, from: 0..<4)
        }
        var auxBits: Int32 = 0
        if data.count >= 8 {
            _ = withUnsafeMutableBytes(of: &auxBits) { ptr in
                data.copyBytes(to: ptr, from: 4..<8)
            }
        }

        enableESP       = (mainBits & bitEspMaster)      != 0
        playerBox       = (mainBits & bitEspBox)          != 0
        topTracer       = (mainBits & bitEspTracer)       != 0
        healthBar       = (mainBits & bitEspHealth)       != 0
        playerName      = (mainBits & bitEspName)         != 0
        distance        = (mainBits & bitEspDistance)     != 0
        espCount        = (mainBits & bitEspCount)        != 0
        espColorEnabled = (mainBits & bitEspColorEnabled) != 0
        showSkeleton    = (mainBits & bitEspSkeleton)     != 0
        silentAim    = (mainBits & bitAimEnabled)   != 0
        let sfRaw    = (auxBits >> auxSilentFovShift) & 0xFF
        silentFov    = sfRaw > 0 ? sfRaw * 2 : 200
        noRecoil     = (mainBits & bitNoRecoil)     != 0
        aimFov       = (mainBits & bitAimFov)       != 0
        aimFovHide   = (mainBits & bitAimFovHide)   != 0
        let modeVal  = (mainBits >> aimModeShift) & 3
        aimMode      = (mainBits & bitStateInitialized) != 0 ? modeVal : 1
        let rateVal  = (mainBits >> headRateShift) & 7
        headRate     = rateVal >= 1 && rateVal <= 4 ? rateVal : 3
        let radiusVal = (auxBits >> auxFovRadiusShift) & 0xFF
        fovRadius    = radiusVal > 0 ? radiusVal * 2 : 150

        fastParachute = (auxBits & bitAuxFastParachute) != 0
        speedRunning  = (auxBits & bitAuxSpeedRunning)  != 0
        fakeDamage    = (auxBits & bitAuxFakeDamage)    != 0
        wideCamera    = (auxBits & bitAuxWideCamera)    != 0
        let fovRaw    = data.count >= 9 ? Int32(data[8]) : 88
        wideCameraFov = fovRaw >= 60 && fovRaw <= 120 ? fovRaw : 88

        // Thickness from bytes 11-13
        lineThicknessRaw  = data.count >= 12 ? Int32(data[11]) : 5
        boxThicknessRaw   = data.count >= 13 ? Int32(data[12]) : 5
        nameThicknessRaw  = data.count >= 14 ? Int32(data[13]) : 5

        // RGB colors from bytes 14-31
        if data.count >= 17 { lineColor   = bytesToColor(r: data[14], g: data[15], b: data[16]) }
        if data.count >= 20 { boxColor    = bytesToColor(r: data[17], g: data[18], b: data[19]) }
        if data.count >= 23 { healthColor = bytesToColor(r: data[20], g: data[21], b: data[22]) }
        if data.count >= 26 { nameColor   = bytesToColor(r: data[23], g: data[24], b: data[25]) }
        if data.count >= 29 { distColor     = bytesToColor(r: data[26], g: data[27], b: data[28]) }
        if data.count >= 32 { countColor    = bytesToColor(r: data[29], g: data[30], b: data[31]) }
        if data.count >= 35 { skeletonColor = bytesToColor(r: data[32], g: data[33], b: data[34]) }
        if data.count >= 38 { fovColor      = bytesToColor(r: data[35], g: data[36], b: data[37]) }
        if data.count >= 39 { skelThicknessRaw = Int32(data[38]) }
    }

    private func flushState() {
        guard let (_, container) = resolvedContainer else { return }

        var mainBits: Int32 = bitStateInitialized
        if enableESP    { mainBits |= bitEspMaster }
        if playerBox    { mainBits |= bitEspBox }
        if topTracer    { mainBits |= bitEspTracer }
        if healthBar    { mainBits |= bitEspHealth }
        if playerName   { mainBits |= bitEspName }
        if distance     { mainBits |= bitEspDistance }
        if espCount        { mainBits |= bitEspCount }
        if espColorEnabled { mainBits |= bitEspColorEnabled }
        if showSkeleton    { mainBits |= bitEspSkeleton }
        if silentAim    { mainBits |= bitAimEnabled }
        if noRecoil     { mainBits |= bitNoRecoil }
        if aimFov       { mainBits |= bitAimFov }
        if aimFovHide   { mainBits |= bitAimFovHide }
        mainBits |= (aimMode & 3) << aimModeShift
        mainBits |= (headRate & 7) << headRateShift
        // NOTE: thickness no longer packed in mainBits (was causing float precision bug in C#)

        var auxBits: Int32 = 0
        if fastParachute { auxBits |= bitAuxFastParachute }
        if speedRunning  { auxBits |= bitAuxSpeedRunning }
        if fakeDamage    { auxBits |= bitAuxFakeDamage }
        if wideCamera    { auxBits |= bitAuxWideCamera }
        auxBits |= ((fovRadius / 2) & 0xFF) << auxFovRadiusShift
        auxBits |= ((silentFov / 2) & 0xFF) << auxSilentFovShift

        var data = Data(count: 60)
        data.withUnsafeMutableBytes { ptr in
            withUnsafeBytes(of: mainBits) { src in
                ptr.baseAddress!.copyMemory(from: src.baseAddress!, byteCount: 4)
            }
            withUnsafeBytes(of: auxBits) { src in
                (ptr.baseAddress! + 4).copyMemory(from: src.baseAddress!, byteCount: 4)
            }
        }
        // byte 8: wideCameraFov (60-120); bytes 9-10: reserved
        data[8] = UInt8(max(60, min(120, wideCameraFov)))
        data[9] = 0; data[10] = 0
        // bytes 11-13: thickness (0-97)
        data[11] = UInt8(min(97, max(0, lineThicknessRaw)))
        data[12] = UInt8(min(97, max(0, boxThicknessRaw)))
        data[13] = UInt8(min(97, max(0, nameThicknessRaw)))
        // bytes 14-31: RGB colors (line, box, health, name, dist, count)
        let espColors: [Color] = [lineColor, boxColor, healthColor, nameColor, distColor, countColor]
        for (i, color) in espColors.enumerated() {
            let (r, g, b) = colorToBytes(color)
            data[14 + i * 3] = r
            data[15 + i * 3] = g
            data[16 + i * 3] = b
        }
        // bytes 32-34: skeleton color; bytes 35-37: FOV color; byte 38: skeleton thickness
        let (sr, sg, sb) = colorToBytes(skeletonColor)
        data[32] = sr; data[33] = sg; data[34] = sb
        let (fr, fg, fb) = colorToBytes(fovColor)
        data[35] = fr; data[36] = fg; data[37] = fb
        data[38] = UInt8(min(97, max(0, skelThicknessRaw)))
        data[39] = 0
        // bytes 40-55: featureToken ASCII (16 bytes); bytes 56-59: h1 int32 LE
        // h1=0 means "no token" — C# skips ESP if h1==0
        if !storedFeatureToken.isEmpty {
            let _tokBytes = Array(storedFeatureToken.utf8.prefix(16))
            for i in 0..<16 { data[40 + i] = i < _tokBytes.count ? _tokBytes[i] : 0 }
            var _h: UInt32 = 0x811C9DC5
            _h = (_h ^ UInt32(data[39])) &* 0x01000193 // byte 39 (ping counter=0 on flush) included in hash
            for i in 40..<56 { _h = (_h ^ UInt32(data[i])) &* 0x01000193 }
            let _salt: [UInt8] = [0x2F,0x8A,0x4C,0xB1,0x73,0xE5,0x1D,0x96,0x5A,0x3F,0xC8,0x07,0xDB,0x62,0x84,0xAE]
            for b in _salt { _h = (_h ^ UInt32(b ^ 0x5B)) &* 0x01000193 }
            let _h1 = Int32(bitPattern: _h ^ 0x5A5AA5A5) & Int32(0x7FFFFFFF)
            data[56] = UInt8(_h1 & 0xFF);           data[57] = UInt8((_h1 >> 8) & 0xFF)
            data[58] = UInt8((_h1 >> 16) & 0xFF);  data[59] = UInt8((_h1 >> 24) & 0xFF)
        }
        // else: bytes 40-59 remain 0 → C# sees h1=0 → ESP disabled

        let docPath = documentsPath(in: container)
        try? FileManager.default.createDirectory(
            atPath: docPath, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: configFilePath(in: container)))
    }

    private func performPatch() async throws -> PatchResult {
        patchLog = []
        addLog("Bắt đầu patch...")

        let variant = await MainActor.run { self.selectedVariant }
        addLog("Variant: \(variant.rawValue)")

        guard let (_, container) = await MainActor.run(resultType: Optional<(String, String)>.self, body: {
            self.resolvedContainer
        }) else {
            let name = variant == .freefire ? "Free Fire" : "Free Fire MAX"
            addLog("Không tìm thấy game container cho \(name)", level: .err)
            throw NSError(
                domain: "FreefireESP", code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Không tìm thấy \(name) trên thiết bị. Hãy cài game trước."])
        }

        let shortContainer = "..." + container.suffix(28)
        addLog("Container: \(shortContainer)", level: .ok)

        guard let patchSrc = Bundle.main.url(
            forResource: "Assembly-CSharp-patch", withExtension: "bytes") else {
            addLog("Không tìm thấy Assembly-CSharp-patch.bytes trong bundle", level: .err)
            throw NSError(
                domain: "FreefireESP", code: 2,
                userInfo: [NSLocalizedDescriptionKey:
                    "File patch chưa được đóng gói vào app. Vui lòng liên hệ tác giả để cập nhật."])
        }

        let fm = FileManager.default
        let docPath = documentsPath(in: container)
        try fm.createDirectory(atPath: docPath, withIntermediateDirectories: true)

        let destBytes = patchBytesPath(in: container)
        try? fm.removeItem(atPath: destBytes)
        do {
            try fm.copyItem(at: patchSrc, to: URL(fileURLWithPath: destBytes))
            if let attr = try? fm.attributesOfItem(atPath: destBytes), let sz = attr[.size] as? Int {
                addLog("Copy bytes: OK (\(sz / 1024) KB)", level: .ok)
            } else {
                addLog("Copy bytes: OK", level: .ok)
            }
        } catch {
            addLog("Copy bytes thất bại: \(error.localizedDescription)", level: .err)
            throw error
        }

        if let configSrc = Bundle.main.url(forResource: "localConfig", withExtension: "json") {
            let destConfig = localConfigPath(in: container)
            try? fm.removeItem(atPath: destConfig)
            try? fm.copyItem(at: configSrc, to: URL(fileURLWithPath: destConfig))
        }

        addLog("Gọi server lấy feature token...")
        let hwid = DeviceIdentity.current
        let licKey = LicenseGateStore.storedKeyCode ?? ""
        let featureToken = await PatchHubService.fetchPatchAuth(licenseKey: licKey, hwid: hwid) ?? ""

        if featureToken.isEmpty {
            addLog("Token: không nhận được từ server (key chưa kích hoạt?)", level: .warn)
        } else {
            addLog("Token: nhận được (\(featureToken.prefix(10))...)", level: .ok)
            await MainActor.run {
                self.storedFeatureToken = featureToken
                self.flushState()
            }
            addLog("ESP cfg token: đã ghi", level: .ok)
        }

        addLog("Ghi token.json...")
        let docsPath = documentsPath(in: container)
        let writeResults = Self.writeTokenJson(featureToken: featureToken, licKey: licKey, docsPath: docsPath)
        for (path, ok) in writeResults {
            let short = path.count > 48 ? "..." + path.suffix(45) : path
            addLog("\(ok ? "✓" : "✗") \(short)", level: ok ? .ok : .warn)
        }

        let tokenPath = (docsPath as NSString).appendingPathComponent("token.json")
        let tokenExists = fm.fileExists(atPath: tokenPath)
        addLog("token.json tại game container: \(tokenExists ? "Tồn tại ✓" : "Không tồn tại ✗")",
               level: tokenExists ? .ok : .err)

        tokenRefreshTask?.cancel()
        tokenRefreshTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                let h = DeviceIdentity.current
                let k = await MainActor.run { LicenseGateStore.storedKeyCode ?? "" }
                let t = await PatchHubService.fetchPatchAuth(licenseKey: k, hwid: h) ?? ""
                let d = await MainActor.run { self.documentsPath(in: container) }
                Self.writeTokenJson(featureToken: t, licKey: k, docsPath: d)
                if !t.isEmpty {
                    let cfgPath = (d as NSString).appendingPathComponent("contentcache/Compulsory/ios/gameassetbundles/ingame/.pdata")
                    if Self.isFridaPresent() {
                        // Frida detected: write invalid h1 so C# kills ESP
                        var bad = (try? Data(contentsOf: URL(fileURLWithPath: cfgPath))) ?? Data(count: 60)
                        while bad.count < 60 { bad.append(0) }
                        bad[39] = 0; bad[56] = 0; bad[57] = 0; bad[58] = 0; bad[59] = 0
                        try? bad.write(to: URL(fileURLWithPath: cfgPath))
                        await MainActor.run { self.storedFeatureToken = ""; self.flushState() }
                    } else {
                        Self.refreshEspCfgToken(featureToken: t, cfgPath: cfgPath)
                        await MainActor.run { self.storedFeatureToken = t }
                    }
                } else {
                    // Server từ chối key (revoked/expired) → xóa token, ghi .pdata với h1=0 → C# tắt ESP
                    await MainActor.run {
                        self.storedFeatureToken = ""
                        self.flushState()
                    }
                }
            }
        }

        addLog("Patch hoàn thành, đang mở game...", level: .ok)
        return .success
    }

    private var tokenRefreshTask: Task<Void, Never>?

    private nonisolated static func refreshEspCfgToken(featureToken: String, cfgPath: String) {
        guard !featureToken.isEmpty,
              var data = try? Data(contentsOf: URL(fileURLWithPath: cfgPath)),
              data.count >= 40 else { return }
        while data.count < 60 { data.append(0) }
        // Increment ping counter (byte 39) so C# detects liveness every 4 min
        data[39] = data[39] &+ 1
        let _tokBytes = Array(featureToken.utf8.prefix(16))
        for i in 0..<16 { data[40 + i] = i < _tokBytes.count ? _tokBytes[i] : 0 }
        var _h: UInt32 = 0x811C9DC5
        _h = (_h ^ UInt32(data[39])) &* 0x01000193 // include new ping counter value in hash
        for i in 40..<56 { _h = (_h ^ UInt32(data[i])) &* 0x01000193 }
        let _salt: [UInt8] = [0x2F,0x8A,0x4C,0xB1,0x73,0xE5,0x1D,0x96,0x5A,0x3F,0xC8,0x07,0xDB,0x62,0x84,0xAE]
        for b in _salt { _h = (_h ^ UInt32(b ^ 0x5B)) &* 0x01000193 }
        let _h1 = Int32(bitPattern: _h ^ 0x5A5AA5A5) & Int32(0x7FFFFFFF)
        data[56] = UInt8(_h1 & 0xFF);           data[57] = UInt8((_h1 >> 8) & 0xFF)
        data[58] = UInt8((_h1 >> 16) & 0xFF);  data[59] = UInt8((_h1 >> 24) & 0xFF)
        try? data.write(to: URL(fileURLWithPath: cfgPath))
    }

    private nonisolated static func isFridaPresent() -> Bool {
        // Check filesystem paths where frida-server lives on jailbroken devices
        let fm = FileManager.default
        for path in ["/usr/lib/frida", "/usr/share/frida", "/usr/bin/frida-server",
                     "/usr/local/bin/frida-server", "/private/var/lib/frida",
                     "/Library/MobileSubstrate/DynamicLibraries/frida.plist"] {
            if fm.fileExists(atPath: path) { return true }
        }
        // Check loaded frameworks via Bundle for Frida gadget injection
        let suspiciousBundles = Bundle.allFrameworks.map { $0.bundlePath.lowercased() }
        for path in suspiciousBundles {
            if path.contains("frida") || path.contains("cynject") || path.contains("libhooker") || path.contains("substitute") {
                return true
            }
        }
        return false
    }

    @discardableResult
    private nonisolated static func writeTokenJson(featureToken: String, licKey: String, docsPath: String) -> [(path: String, ok: Bool)] {
        let _ts = Int64(Date().timeIntervalSince1970)
        var _h: UInt32 = 0
        let _bs = "\(featureToken):\(licKey):\(_ts)"
        for _c in _bs.unicodeScalars { _h = (_h ^ UInt32(_c.value)) &* 0x01000193 }
        let _salt: [UInt8] = [0x2F, 0x8A, 0x4C, 0xB1, 0x73, 0xE5, 0x1D, 0x96,
                              0x5A, 0x3F, 0xC8, 0x07, 0xDB, 0x62, 0x84, 0xAE]
        for _b in _salt { _h = (_h ^ UInt32(_b ^ 0x5B)) &* 0x01000193 }
        // Store as plain integers — avoids all hex string formatting issues.
        let _h1 = Int64(_h ^ 0x5A5AA5A5) & 0x7FFFFFFF
        let _h2 = Int64(_h ^ 0x3C4D5E6F) & 0x7FFFFFFF
        let _json = "{\"tok\":\"\(featureToken)\",\"key\":\"\(licKey)\",\"ts\":\(_ts),\"h1\":\(_h1),\"h2\":\(_h2)}"
        let _jd = Data(_json.utf8)
        let _paths: [String] = [
            (docsPath as NSString).appendingPathComponent("token.json"),
            "/var/mobile/Media/Downloads/token.json",
            "/tmp/token.json",
            "/private/var/tmp/token.json"
        ]
        var _results: [(String, Bool)] = []
        for _p in _paths {
            var _ok = false
            do { try _jd.write(to: URL(fileURLWithPath: _p)); _ok = true } catch {}
            _results.append((_p, _ok))
        }
        return _results
    }
}
