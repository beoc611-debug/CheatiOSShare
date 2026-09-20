import Foundation
import MachO
import CryptoKit

enum TamperDetector {
    // System path prefixes — same list as server side
    private static let systemPrefixes = [
        "/System/", "/usr/lib/", "/Library/Developer/",
        "/private/preboot/Cryptexes/"   // iOS 16+ Cryptex volume (Apple system libs)
    ]

    // Known injection pattern names — local fast-check before server validation
    private static let suspiciousPatterns = [
        "cydiasubstrate", "mobilesubstrate", "libsubstrate", "substitute",
        "fridagadget", "frida", "libhooker", "tweakinject", "ellekit",
        "choicy", "rocketbootstrap", "libdopamine", "shadowhook", "dobby",
        "cynject", "sbinject", "mryipc", "appinject", "pspawn"
    ]

    /// SHA256 of the first 64 KB of the app binary (arm64 slice).
    /// Matches what the server computes from the original IPA.
    static func binaryHash() -> String? {
        guard let url = Bundle.main.executableURL,
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        let sample = data.prefix(64 * 1024)
        let digest = SHA256.hash(data: sample)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    struct ScanResult {
        /// Fast local check: pattern-matched suspicious dylibs found
        let hasLocalSuspicion: Bool
        /// All non-system dylibs loaded at runtime (sent to server for baseline comparison)
        let nonSystemDylibs: [String]
        /// SHA256 of first 64KB of binary
        let binaryHash: String?
    }

    /// Collect all loaded dylibs, split into non-system and suspicious buckets.
    static func scan() -> ScanResult {
        var nonSystem: [String] = []

        let count = _dyld_image_count()
        for i in 0..<count {
            guard let nameCStr = _dyld_get_image_name(i) else { continue }
            let libPath = String(cString: nameCStr)
            if !systemPrefixes.contains(where: { libPath.hasPrefix($0) }) {
                nonSystem.append(libPath)
            }
        }

        // Frameworks folder scan — catches dylibs placed but not loaded (eSign inject, manual drop)
        // Original app has no .dylib files in Frameworks; any found = injection.
        let fwFolder = Bundle.main.bundlePath + "/Frameworks"
        if let fwContents = try? FileManager.default.contentsOfDirectory(atPath: fwFolder) {
            for file in fwContents where file.hasSuffix(".dylib") {
                // Add with marker path if not already in the loaded-dylib list
                if !nonSystem.contains(where: { $0.hasSuffix("/" + file) }) {
                    nonSystem.append("@executable_path/Frameworks/" + file)
                }
            }
        }

        // DYLD_INSERT_LIBRARIES injection vector
        let hasDyldEnv = ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"] != nil
        let hasPattern = nonSystem.contains(where: { path in
            let lower = path.lowercased()
            return suspiciousPatterns.contains(where: { lower.contains($0) })
        })

        return ScanResult(
            hasLocalSuspicion: hasPattern || hasDyldEnv,
            nonSystemDylibs: nonSystem,
            binaryHash: binaryHash()
        )
    }

    /// Report dylib list to server. Server compares against IPA baseline.
    /// Returns true if server confirmed tampering (baseline exceeded or pattern found).
    /// Send dylib list + binary hash to server for baseline comparison.
    /// Returns true if server confirmed tampering.
    @discardableResult
    static func report(scan: ScanResult, reason: String = "startup_check") async -> Bool {
        guard let url = URL(string: PatchHubService.baseURL.absoluteString + "/" + PatchHubService.pathSecurity) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(PatchHubService.clientToken, forHTTPHeaderField: "X-App-Token")
        req.setValue(DeviceIdentity.current, forHTTPHeaderField: "X-Device-Id")
        var body: [String: Any] = [
            "reason": reason,
            "dylibs": Array(scan.nonSystemDylibs.prefix(50))
        ]
        if let hash = scan.binaryHash { body["binaryHash"] = hash }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await PinnedSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return json["tampered"] as? Bool ?? false
    }
}
