import Foundation
import UIKit

// Manages Free Fire ESP state by reading/writing a config file in the game's
// Documents/ folder. The game reads the same file every ~1 second via the
// patched ESPLogic (replacing the old in-game 3-finger menu).
//
// Config file format (esp_cfg, 8 bytes):
//   bytes 0-3 : int32 LE — main state bits
//   bytes 4-7 : int32 LE — aux state bits (1=FastParachute, 2=SpeedRunning)
//
// Main state bit constants (must match ESPLogic.template.cs):
//   EspMaster=1, EspBox=2, EspTracer=4, EspHealth=8, EspName=16, EspDistance=32
//   StateInitialized=128, AimEnabled=32768, NoRecoil=262144
//   AimModeShift=16 (aimMode=2 → 131072), HeadRateShift=19 (headRate=3 → 1572864)

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
    private let bitAimFovHide:      Int32 = 16777216
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

    // AIM tab
    @Published var silentAim    = false
    @Published var silentFov: Int32 = 200  // 0=no limit, else radius in px (stored /2 in 8 bits)
    @Published var noRecoil     = false
    // Aim FOV system (AimSystemEnabled)
    @Published var aimFov       = false
    @Published var aimFovHide   = false
    @Published var fovRadius: Int32 = 100   // 30-200 screen pixels
    // 0=Body, 1=Head, 2=Mixed — used by Aim FOV
    @Published var aimMode: Int32 = 1
    // 1=25%, 2=50%, 3=75%, 4=100%
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

    // MARK: - Public interface

    /// Detects both FF and FF MAX containers, reads state from selected variant.
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

    /// Switch target game and re-read state.
    func selectVariant(_ variant: FFVariant) {
        selectedVariant = variant
        if let (_, container) = resolvedContainer {
            readState(from: container)
            flushState()
        }
    }

    /// Toggle one of the @Published Bool properties and flush to disk.
    func toggle(_ keyPath: ReferenceWritableKeyPath<FreefireESPStore, Bool>) {
        self[keyPath: keyPath].toggle()
        flushState()
    }

    /// Set a specific property and flush to disk.
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
        fovRadius = max(30, min(200, radius))
        flushState()
    }

    /// Xóa patch file và esp_cfg khỏi Documents/ của game.
    func removePatches() {
        guard let (_, container) = resolvedContainer else { return }
        let fm = FileManager.default
        try? fm.removeItem(atPath: patchBytesPath(in: container))
        try? fm.removeItem(atPath: configFilePath(in: container))
        refresh()
    }

    /// Mở game sau khi patch thành công.
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

    /// Copy the bundled patch bytes into the game's Documents/ folder.
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

        enableESP    = (mainBits & bitEspMaster)   != 0
        playerBox    = (mainBits & bitEspBox)       != 0
        topTracer    = (mainBits & bitEspTracer)    != 0
        healthBar    = (mainBits & bitEspHealth)    != 0
        playerName   = (mainBits & bitEspName)      != 0
        distance     = (mainBits & bitEspDistance)  != 0
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
        fovRadius    = radiusVal > 0 ? radiusVal : 100

        fastParachute = (auxBits & bitAuxFastParachute) != 0
        speedRunning  = (auxBits & bitAuxSpeedRunning)  != 0
        fakeDamage    = (auxBits & bitAuxFakeDamage)    != 0
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
        if silentAim    { mainBits |= bitAimEnabled }
        if noRecoil     { mainBits |= bitNoRecoil }
        if aimFov       { mainBits |= bitAimFov }
        if aimFovHide   { mainBits |= bitAimFovHide }
        mainBits |= (aimMode & 3) << aimModeShift
        mainBits |= (headRate & 7) << headRateShift

        var auxBits: Int32 = 0
        if fastParachute { auxBits |= bitAuxFastParachute }
        if speedRunning  { auxBits |= bitAuxSpeedRunning }
        if fakeDamage    { auxBits |= bitAuxFakeDamage }
        auxBits |= (fovRadius & 0xFF) << auxFovRadiusShift
        auxBits |= ((silentFov / 2) & 0xFF) << auxSilentFovShift

        var data = Data(count: 8)
        data.withUnsafeMutableBytes { ptr in
            withUnsafeBytes(of: mainBits) { src in
                ptr.baseAddress!.copyMemory(from: src.baseAddress!, byteCount: 4)
            }
            withUnsafeBytes(of: auxBits) { src in
                (ptr.baseAddress! + 4).copyMemory(from: src.baseAddress!, byteCount: 4)
            }
        }

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

        // Copy Assembly-CSharp-patch.bytes
        let destBytes = patchBytesPath(in: container)
        try? fm.removeItem(atPath: destBytes)
        try fm.copyItem(at: patchSrc, to: URL(fileURLWithPath: destBytes))

        // Copy localConfig.json if bundled (optional — skip silently if absent)
        if let configSrc = Bundle.main.url(forResource: "localConfig", withExtension: "json") {
            let destConfig = localConfigPath(in: container)
            try? fm.removeItem(atPath: destConfig)
            try? fm.copyItem(at: configSrc, to: URL(fileURLWithPath: destConfig))
        }

        return .success
    }
}
