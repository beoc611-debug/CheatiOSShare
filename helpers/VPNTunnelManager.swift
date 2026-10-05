import NetworkExtension
import Foundation

@MainActor
final class VPNTunnelManager: ObservableObject {

    static let shared = VPNTunnelManager()
    private init() {}

    private let tunnelBundleID = "com.apple.mobile.MobileHouseArrest.Tunnel"

    @Published var isRunning: Bool = false

    func startIfNeeded() {
        guard !isRunning else { return }
        Task { await loadAndStart() }
    }

    func stopIfRunning() {
        guard isRunning else { return }
        Task { await loadAndStop() }
    }

    private func loadAndStart() async {
        do {
            let mgr = try await loadManager()
            mgr.isEnabled = true
            try await mgr.saveToPreferences()
            try mgr.connection.startVPNTunnel()
            isRunning = true
        } catch {
            print("[VPNTunnelManager] start error: \(error)")
        }
    }

    private func loadAndStop() async {
        do {
            let mgr = try await loadManager()
            mgr.connection.stopVPNTunnel()
            isRunning = false
        } catch {
            print("[VPNTunnelManager] stop error: \(error)")
        }
    }

    private func loadManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let existing = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == tunnelBundleID
        }) {
            return existing
        }
        let mgr = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = tunnelBundleID
        proto.serverAddress = "bypass"
        mgr.protocolConfiguration = proto
        mgr.localizedDescription = "CheatiOSShare Bypass"
        try await mgr.saveToPreferences()
        return mgr
    }
}
