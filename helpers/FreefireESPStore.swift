import Foundation
import UIKit
import SwiftUI

// Manages Free Fire ESP state by reading/writing a config file in the game's
// Documents/ folder. The game reads the same file every ~1 second via the
// patched ESPLogic (replacing the old in-game 3-finger menu).
//
// Config file format (esp_cfg, 32 bytes):
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

    // MARK: - Status
    @Published var selectedVariant: FFVariant = .freefire
    @Published var detectedBundleID: String?
    @Published var detectedMAXBundleID: String?
    @Published var isPatchInstalled    = false
    @Published var isPatchInstalledMAX = false
    @Published var isPatching        = false
    @Published var patchResult: PatchResult?

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
        (documentsPath(in: container) as NSString).appendingPathComponent("esp_cfg")
    }

    private func patchBytesPath(in container: String) -> String {
        (documentsPath(in: container) as NSString)
            .appendingPathComponent("Assembly-CSharp-patch.bytes")
    }

    private func localConfigPath(in container: String) -> String {
        (documentsPath(in: container) as NSString)
            .appendingPathComponent("localConfig.json")
    }

    private func espTokenPath(in container: String) -> String {
        (documentsPath(in: container) as NSString).appendingPathComponent("esp_tok")
    }

    private func espHwidPath(in container: String) -> String {
        (documentsPath(in: container) as NSString).appendingPathComponent("esp_hwid")
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

    func removePatches() {
        guard let (_, container) = resolvedContainer else { return }
        let fm = FileManager.default
        try? fm.removeItem(atPath: patchBytesPath(in: container))
        try? fm.removeItem(atPath: configFilePath(in: container))
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
        auxBits |= ((fovRadius / 2) & 0xFF) << auxFovRadiusShift
        auxBits |= ((silentFov / 2) & 0xFF) << auxSilentFovShift

        var data = Data(count: 40)
        data.withUnsafeMutableBytes { ptr in
            withUnsafeBytes(of: mainBits) { src in
                ptr.baseAddress!.copyMemory(from: src.baseAddress!, byteCount: 4)
            }
            withUnsafeBytes(of: auxBits) { src in
                (ptr.baseAddress! + 4).copyMemory(from: src.baseAddress!, byteCount: 4)
            }
        }
        // bytes 8-10: reserved (zero)
        data[8] = 0; data[9] = 0; data[10] = 0
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

        let docPath = documentsPath(in: container)
        try? FileManager.default.createDirectory(
            atPath: docPath, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: configFilePath(in: container)))
    }

    private func performPatch() async throws -> PatchResult {
        let variant = await MainActor.run { self.selectedVariant }
        guard let (_, container) = await MainActor.run(resultType: Optional<(String, String)>.self, body: {
            self.resolvedContainer
        }) else {
            let name = variant == .freefire ? "Free Fire" : "Free Fire MAX"
            throw NSError(
                domain: "FreefireESP", code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Không tìm thấy \(name) trên thiết bị. Hãy cài game trước."])
        }

        guard let patchSrc = Bundle.main.url(
            forResource: "Assembly-CSharp-patch", withExtension: "bytes") else {
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
        try fm.copyItem(at: patchSrc, to: URL(fileURLWithPath: destBytes))

        if let configSrc = Bundle.main.url(forResource: "localConfig", withExtension: "json") {
            let destConfig = localConfigPath(in: container)
            try? fm.removeItem(atPath: destConfig)
            try? fm.copyItem(at: configSrc, to: URL(fileURLWithPath: destConfig))
        }

        // Write epoch timestamp to esp_tok so game can check session age (15 min = 900s).
        let patchedAt = String(Int64(Date().timeIntervalSince1970))
        try? patchedAt.write(
            toFile: espTokenPath(in: container), atomically: true, encoding: .utf8)
        // Notify server of patch — validates key+hwid, updates TOKEN in admin panel.
        let hwid = DeviceIdentity.current
        let licKey = LicenseGateStore.storedKeyCode ?? ""
        await PatchHubService.fetchPatchAuth(licenseKey: licKey, hwid: hwid)

        return .success
    }
}
