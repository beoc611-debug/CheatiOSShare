import NetworkExtension
import Foundation

@MainActor
final class NEDNSManager: ObservableObject {
    static let shared = NEDNSManager()
    private init() {}

    @Published var activeProfileID: String? = nil
    @Published var isEnabled: Bool = false

    private let idKey = "ne_dns_active_profile_id"
    private var mgr: NEDNSSettingsManager { NEDNSSettingsManager.shared() }

    func load() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            mgr.loadFromPreferences { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { cont.resume(); return }
                    self.isEnabled = self.mgr.isEnabled
                    self.activeProfileID = self.isEnabled
                        ? UserDefaults.standard.string(forKey: self.idKey)
                        : nil
                    cont.resume()
                }
            }
        }
    }

    func activate(profileID: String, dohURL: String) async -> Bool {
        guard let url = URL(string: dohURL) else { return false }
        do {
            try await loadPrefs()
            let settings = NEDNSOverHTTPSSettings(servers: [url.absoluteString])
            let wifi = NEOnDemandRuleConnect(); wifi.interfaceTypeMatch = .wiFi
            let cell = NEOnDemandRuleConnect(); cell.interfaceTypeMatch = .cellular
            mgr.dnsSettings   = settings
            mgr.onDemandRules = [wifi, cell]
            try await savePrefs()
            UserDefaults.standard.set(profileID, forKey: idKey)
            activeProfileID = profileID
            isEnabled = true
            return true
        } catch {
            print("[NEDNSManager] activate error: \(error)")
            return false
        }
    }

    func deactivate() async -> Bool {
        do {
            try await loadPrefs()
            mgr.dnsSettings   = nil
            mgr.onDemandRules = []
            try await savePrefs()
            UserDefaults.standard.removeObject(forKey: idKey)
            activeProfileID = nil
            isEnabled = false
            return true
        } catch {
            print("[NEDNSManager] deactivate error: \(error)")
            return false
        }
    }

    private func loadPrefs() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            mgr.loadFromPreferences { error in
                if let e = error { cont.resume(throwing: e) } else { cont.resume() }
            }
        }
    }

    private func savePrefs() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            mgr.saveToPreferences { error in
                if let e = error { cont.resume(throwing: e) } else { cont.resume() }
            }
        }
    }
}
