import UIKit

struct InstalledApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let containerPath: String
    let version: String
    let icon: UIImage?

    var id: String { bundleID }
    var displayName: String { name.isEmpty ? bundleID : name }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
final class InstalledAppService: ObservableObject {
    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var isLoading = false

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let loaded = await Task.detached(priority: .userInitiated) {
            self.buildAppList()
        }.value
        apps = loaded.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    nonisolated private func buildAppList() -> [InstalledApp] {
        var result: [InstalledApp] = []
        var seen = Set<String>()

        // Primary: MCM class-2 enumeration
        var enumError: NSString?
        let identifiers = MCMEnumerateIdentifiersForClass(2, 4096, &enumError)

        for bundleID in identifiers {
            guard seen.insert(bundleID).inserted else { continue }
            var pathError: NSString?
            guard let container = MCMFilzaDataContainerPath(bundleID, &pathError) else { continue }
            let info = appInfo(for: bundleID)
            result.append(InstalledApp(
                bundleID: bundleID,
                name: info.name,
                containerPath: container,
                version: info.version,
                icon: info.icon
            ))
        }

        // Fallback: LaunchServices workspace
        if result.isEmpty {
            if let workspace = NSClassFromString("LSApplicationWorkspace"),
               let ws = (workspace as AnyObject).perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() {
                let apps = (ws as AnyObject).perform(NSSelectorFromString("allApplications"))?.takeUnretainedValue() as? [AnyObject] ?? []
                for proxy in apps {
                    let bid = (proxy.perform(NSSelectorFromString("applicationIdentifier"))?.takeUnretainedValue() as? String) ??
                              (proxy.perform(NSSelectorFromString("bundleIdentifier"))?.takeUnretainedValue() as? String) ?? ""
                    guard !bid.isEmpty, seen.insert(bid).inserted else { continue }
                    var pathError: NSString?
                    guard let container = MCMFilzaDataContainerPath(bid, &pathError) else { continue }
                    let info = appInfo(for: bid)
                    result.append(InstalledApp(bundleID: bid, name: info.name,
                                               containerPath: container,
                                               version: info.version, icon: info.icon))
                }
            }
        }

        return result
    }

    nonisolated private func appInfo(for bundleID: String) -> (name: String, version: String, icon: UIImage?) {
        var name = ""
        var version = ""
        var icon: UIImage?

        let bundleRoots = [
            "/var/containers/Bundle/Application",
            "/Applications",
            "/System/Applications"
        ]

        for root in bundleRoots {
            let fm = FileManager.default
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries {
                var container = (root as NSString).appendingPathComponent(entry)
                if UUID(uuidString: entry) != nil {
                    // Nested .app
                    guard let children = try? fm.contentsOfDirectory(atPath: container),
                          let appDir = children.first(where: { $0.hasSuffix(".app") }) else { continue }
                    container = (container as NSString).appendingPathComponent(appDir)
                }
                let infoPath = (container as NSString).appendingPathComponent("Info.plist")
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: infoPath)),
                      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                      (plist["CFBundleIdentifier"] as? String) == bundleID else { continue }

                name = (plist["CFBundleDisplayName"] as? String) ??
                       (plist["CFBundleName"] as? String) ?? bundleID
                version = plist["CFBundleShortVersionString"] as? String ?? ""

                let iconFiles = (plist["CFBundleIcons"] as? [String: Any])?["CFBundlePrimaryIcon"] as? [String: Any]
                let iconName = (iconFiles?["CFBundleIconFiles"] as? [String])?.last ?? ""
                if !iconName.isEmpty {
                    let iconPath = (container as NSString).appendingPathComponent(iconName)
                    icon = UIImage(contentsOfFile: iconPath) ??
                           UIImage(contentsOfFile: iconPath + "@2x.png") ??
                           UIImage(contentsOfFile: iconPath + ".png")
                }
                return (name, version, icon)
            }
        }
        return (bundleID, "", nil)
    }
}
