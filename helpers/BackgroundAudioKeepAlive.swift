import AVFoundation
import UIKit

/// Plays a silent audio loop to prevent iOS from suspending the app
/// while the user is in-game. Without this, iOS suspends background apps
/// after ~30s, causing the token refresh task to freeze and ESP to turn off.
final class BackgroundAudioKeepAlive {
    static let shared = BackgroundAudioKeepAlive()

    private var player: AVAudioPlayer?
    private var isActive = false

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc private func appDidEnterBackground() {
        start()
    }

    @objc private func appWillEnterForeground() {
        stop()
    }

    func start() {
        guard !isActive else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        // 0.1s of silence as WAV: 44-byte header + 4410 zero samples (16-bit mono 44100Hz)
        let wav = Self.makeSilentWav(durationMs: 100)
        guard let p = try? AVAudioPlayer(data: wav) else { return }
        p.numberOfLoops = -1  // loop forever
        p.volume = 0.0
        p.play()
        player = p
        isActive = true
    }

    func stop() {
        player?.stop()
        player = nil
        isActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // Build a minimal silent WAV in memory — no file needed
    private static func makeSilentWav(durationMs: Int) -> Data {
        let sampleRate: Int = 44100
        let numSamples = sampleRate * durationMs / 1000
        let dataSize = numSamples * 2  // 16-bit = 2 bytes per sample
        let fileSize = 36 + dataSize

        var d = Data()
        func w32(_ v: Int) { var x = UInt32(v).littleEndian; d.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) }) }
        func w16(_ v: Int) { var x = UInt16(v).littleEndian; d.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) }) }

        d.append(contentsOf: "RIFF".utf8); w32(fileSize)
        d.append(contentsOf: "WAVE".utf8)
        d.append(contentsOf: "fmt ".utf8); w32(16); w16(1); w16(1)
        w32(sampleRate); w32(sampleRate * 2); w16(2); w16(16)
        d.append(contentsOf: "data".utf8); w32(dataSize)
        d.append(Data(count: dataSize))  // silence = all zeros
        return d
    }
}
