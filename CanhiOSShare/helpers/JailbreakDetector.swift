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
        let suspicious = ["MobileSubstrate", "CydiaSubstrate", "Substitute", "libhooker", "TweakInject", "ElleKit"]
        let count = _dyld_image_count()
        for i in 0..<count {
            guard let cName = _dyld_get_image_name(i) else { continue }
            let name = String(cString: cName)
            if suspicious.contains(where: { name.localizedCaseInsensitiveContains($0) }) {
                return true
            }
        }
        return false
    }
}
