import Foundation
import MachO
import CryptoKit
import Network

enum TamperDetector {
    // System path prefixes — same list as server side
    private static let systemPrefixes = [
        "/System/", "/usr/lib/", "/Library/Developer/",
        "/private/preboot/Cryptexes/"   // iOS 16+ Cryptex volume (Apple system libs)
    ]

    // File extensions that are never Mach-O binaries — skip magic check for these
    private static let safeExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "svg", "icns",
        "plist", "strings", "stringsdict",
        "nib", "storyboardc", "car",
        "html", "css", "js", "json", "txt", "xml",
        "ttf", "otf", "woff", "woff2",
        "mp3", "mp4", "m4a", "mov", "aac",
        "mobileprovision", "lproj"
    ]

    // Read first 4 bytes and check for Mach-O / fat-binary magic — catches renamed dylibs
    private static func isMachOBinary(_ path: String) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        let data = handle.readData(ofLength: 4)
        handle.closeFile()
        guard data.count == 4 else { return false }
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        return magic == 0xFEEDFACE || magic == 0xFEEDFACF ||  // MH_MAGIC / MH_MAGIC_64
               magic == 0xCAFEBABE || magic == 0xBEBAFECA ||  // FAT_MAGIC / FAT_CIGAM
               magic == 0xCEFAEDFE || magic == 0xCFFAEDFE     // MH_CIGAM / MH_CIGAM_64
    }

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
        let hasLocalSuspicion: Bool
        let hasInjectedBinary: Bool  // unknown Mach-O found in bundle (block without server)
        let hasNameChange: Bool      // app name or display name was altered (crash, no ban)
        let nonSystemDylibs: [String]
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

        // Scan app bundle for injected binaries not loaded by dyld (eSign/manual drop)
        // Detects by Mach-O magic bytes — catches renamed dylibs and .framework bundles
        let bundlePath = Bundle.main.bundlePath
        let execName = Bundle.main.executableURL?.lastPathComponent ?? ""
        var foundInjectedBinary = false

        // Scans a flat directory; recurses one level into .framework subdirs
        func scanDir(_ dir: String, prefix: String, skipName: String? = nil) {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
            for file in contents {
                if let skip = skipName, file == skip { continue }
                let fullPath = dir + "/" + file
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }
                if isDir.boolValue {
                    // Recurse into .framework bundles (e.g. Frameworks/Evil.framework/binary)
                    if file.hasSuffix(".framework") {
                        scanDir(fullPath, prefix: prefix + file + "/")
                    }
                    continue
                }
                let ext = (file as NSString).pathExtension.lowercased()
                guard !safeExtensions.contains(ext) else { continue }
                if ext == "dylib" || isMachOBinary(fullPath) {
                    foundInjectedBinary = true
                    if !nonSystem.contains(where: { $0.hasSuffix("/" + file) }) {
                        nonSystem.append(prefix + file)
                    }
                }
            }
        }

        scanDir(bundlePath, prefix: "@executable_path/", skipName: execName)
        scanDir(bundlePath + "/Frameworks", prefix: "@executable_path/Frameworks/")

        // DYLD_INSERT_LIBRARIES injection vector
        let hasDyldEnv = ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"] != nil
        let hasPattern = nonSystem.contains(where: { path in
            let lower = path.lowercased()
            return suspiciousPatterns.contains(where: { lower.contains($0) })
        })

        // App name/icon rename detection — crash without ban
        // Skip if user intentionally enabled fake-app disguise mode
        let fakeMode = UserDefaults.standard.bool(forKey: "fakeAppEnabled")
        let info = Bundle.main.infoDictionary
        let displayName = info?["CFBundleDisplayName"] as? String ?? ""
        let bundleName  = info?["CFBundleName"] as? String ?? ""
        // Both names are ours: "CheatiOSVip DSW" (default) or "Flappy Bird" (fake mode written)
        let validDisplay = displayName == "CheatiOSVip DSW" || displayName == "Flappy Bird"
        let nameChanged  = !fakeMode && (!validDisplay || bundleName != "CheatiOSShare")

        return ScanResult(
            hasLocalSuspicion: hasPattern || hasDyldEnv,
            hasInjectedBinary: foundInjectedBinary,
            hasNameChange: nameChanged,
            nonSystemDylibs: nonSystem,
            binaryHash: binaryHash()
        )
    }

    /// Ban report via URLSession.shared (5s timeout).
    private static func reportBanHTTP(bodyData: Data) async {
        guard let url = URL(string: PatchHubService.baseURL.absoluteString + "/" + PatchHubService.pathSecurity) else { return }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(PatchHubService.clientToken, forHTTPHeaderField: "X-App-Token")
        req.setValue(DeviceIdentity.current, forHTTPHeaderField: "X-Device-Id")
        req.httpBody = bodyData
        _ = try? await URLSession.shared.data(for: req)
    }

    /// Ban report via NWConnection raw TLS — bypasses URLSession hooks injected tweaks may install.
    private static func reportBanNW(bodyData: Data) async {
        guard let host = PatchHubService.baseURL.host else { return }
        var hdr  = "POST /\(PatchHubService.pathSecurity) HTTP/1.1\r\n"
        hdr += "Host: \(host)\r\n"
        hdr += "Content-Type: application/json\r\n"
        hdr += "X-App-Token: \(PatchHubService.clientToken)\r\n"
        hdr += "X-Device-Id: \(DeviceIdentity.current)\r\n"
        hdr += "Content-Length: \(bodyData.count)\r\n"
        hdr += "Connection: close\r\n\r\n"
        let payload = hdr.data(using: .utf8)! + bodyData
        let conn = NWConnection(host: NWEndpoint.Host(host), port: 443, using: .tls)
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            var done = false
            func finish() { guard !done else { return }; done = true; conn.cancel(); cont.resume() }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) { finish() }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    conn.send(content: payload, completion: .contentProcessed { _ in
                        // Wait for at least 1 byte of server response before closing —
                        // ensures server has received and processed the ban before abort()
                        conn.receive(minimumIncompleteLength: 1, maximumLength: 256) { _, _, _, _ in
                            finish()
                        }
                    })
                case .failed(_), .cancelled: finish()
                default: break
                }
            }
            conn.start(queue: .global(qos: .userInitiated))
        }
    }

    /// Race URLSession and NWConnection — whichever reaches server first wins, then abort().
    /// Injected dylibs may hook URLSession; NWConnection operates below URLSession hooks.
    static func reportBan(scan: ScanResult) async {
        var body: [String: Any] = ["reason": "dylib_injection", "dylibs": Array(scan.nonSystemDylibs.prefix(50))]
        if let hash = scan.binaryHash { body["binaryHash"] = hash }
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await reportBanHTTP(bodyData: bodyData) }
            group.addTask { await reportBanNW(bodyData: bodyData) }
            _ = await group.next()   // whichever finishes first
            group.cancelAll()
        }
    }

    /// Startup-check report. Returns true if server confirmed tampering.
    @discardableResult
    static func report(scan: ScanResult, reason: String = "startup_check") async -> Bool {
        guard let url = URL(string: PatchHubService.baseURL.absoluteString + "/" + PatchHubService.pathSecurity) else { return false }
        var req = URLRequest(url: url, timeoutInterval: 8)
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
        func parse(_ data: Data) -> Bool {
            (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["tampered"] as? Bool ?? false
        }
        if let (data, _) = try? await PinnedSession.shared.data(for: req) { return parse(data) }
        if let (data, _) = try? await URLSession.shared.data(for: req) { return parse(data) }
        return false
    }
}
