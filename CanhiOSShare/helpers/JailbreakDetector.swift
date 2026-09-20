import Foundation
import MachO

enum JailbreakDetector {
    static func isJailbroken() -> Bool {
        hasJailbreakFiles() || hasInjectedDylibs()
    }

    private static func hasJailbreakFiles() -> Bool {
        let paths: [String] = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Applications/Installer5.app",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/usr/bin/ssh",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/var/jb",
            "/private/preboot/procursus",
        ]
        let fm = FileManager.default
        return paths.contains { fm.fileExists(atPath: $0) }
    }

    private static func hasInjectedDylibs() -> Bool {
        // Known hook framework names (attacker can rename, so this alone isn't enough)
        let knownBad = [
            "MobileSubstrate", "CydiaSubstrate", "Substitute", "libhooker",
            "TweakInject", "ElleKit", "cynject", "rocketbootstrap", "flexloader",
            "libhooker", "libellekit"
        ]
        // Paths where ALL legitimate dylibs must live on a stock device
        let allowedPrefixes: [String] = [
            "/System/Library/",
            "/usr/lib/",
            "/Library/Apple/",
            "/private/preboot/",   // Xcode/DevSupport on dev devices
            Bundle.main.bundlePath // our own embedded frameworks
        ]
        let count = _dyld_image_count()
        for i in 0..<count {
            guard let cName = _dyld_get_image_name(i) else { continue }
            let name = String(cString: cName)
            // Name-based check (fast, catches common frameworks even if path looks ok)
            if knownBad.contains(where: { name.localizedCaseInsensitiveContains($0) }) {
                return true
            }
            // Path-based check: any dylib NOT in a known safe location is injected
            if !allowedPrefixes.contains(where: { name.hasPrefix($0) }) {
                return true
            }
        }
        return false
    }
}
