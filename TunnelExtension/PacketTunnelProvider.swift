import NetworkExtension
import Libbox

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var server: LibboxCommandServer?
    private var startCompletion: ((Error?) -> Void)?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        startCompletion = completionHandler
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                try self.boot()
            } catch {
                self.startCompletion?(error)
                self.startCompletion = nil
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        var err: NSError?
        _ = server?.closeService(&err)
        server = nil
        completionHandler()
    }

    // MARK: - Private

    private func boot() throws {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.apple.mobile.MobileHouseArrest"
        ) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let workDir = container.appendingPathComponent("singbox")
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        let tmpDir  = workDir.appendingPathComponent("tmp")
        try? FileManager.default.createDirectory(at: tmpDir,  withIntermediateDirectories: true)

        let opts = LibboxSetupOptions()
        opts.basePath    = workDir.path
        opts.workingPath = workDir.path
        opts.tempPath    = tmpDir.path
        opts.logMaxLines = 300

        var err: NSError?
        guard LibboxSetup(opts, &err) else {
            throw err ?? makeErr("LibboxSetup failed", -1)
        }

        let platform = TunnelPlatform(provider: self)
        server = LibboxNewCommandServer(nil, platform, &err)
        if let e = err { throw e }
        guard server != nil else { throw makeErr("CommandServer nil", -2) }

        let config = try loadConfig()
        guard server!.startOrReloadService(config, options: nil, error: &err) else {
            throw err ?? makeErr("startOrReloadService failed", -3)
        }

        startCompletion?(nil)
        startCompletion = nil
    }

    private func loadConfig() throws -> String {
        guard let url = Bundle.main.url(forResource: "bypass_config", withExtension: "json"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw makeErr("bypass_config.json missing from bundle", -10)
        }
        return text
    }

    private func makeErr(_ msg: String, _ code: Int) -> NSError {
        NSError(domain: "SBTunnel", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

// MARK: - Platform Interface

private class TunnelPlatform: NSObject, LibboxPlatformInterface {

    unowned let provider: NEPacketTunnelProvider

    init(provider: NEPacketTunnelProvider) { self.provider = provider }

    func openTun(_ options: LibboxTunOptions?, ret0_: UnsafeMutablePointer<Int32>?, error: NSErrorPointer) -> Bool {
        let mtu = options?.getMTU() ?? 1500
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "192.0.0.1")
        settings.mtu = NSNumber(value: mtu)

        let ipv4 = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(addresses: ["fdfe:dcba:9876::1"], networkPrefixLengths: [NSNumber(value: 126)])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        settings.dnsSettings = NEDNSSettings(servers: ["198.18.0.1", "1.1.1.1"])

        let sema = DispatchSemaphore(value: 0)
        provider.setTunnelNetworkSettings(settings) { _ in sema.signal() }
        sema.wait()

        // Private API — returns the utun fd created by NEPacketTunnelProvider
        if let fd = (provider.packetFlow as AnyObject).value(forKey: "socket.fileDescriptor") as? Int32, fd >= 0 {
            ret0_?.pointee = fd
            return true
        }
        error?.pointee = NSError(domain: "SBTunnel", code: -4,
                                 userInfo: [NSLocalizedDescriptionKey: "Cannot obtain TUN fd"])
        return false
    }

    func autoDetectInterfaceControl(_ fd: Int32, error: NSErrorPointer) -> Bool { return true }
    func usePlatformAutoDetectInterfaceControl() -> Bool { return true }
    func underNetworkExtension() -> Bool { return true }
    func usePlatformBridge() -> Bool { return false }
    func usePlatformShell() -> Bool { return false }
    func useProcFS() -> Bool { return false }
    func includeAllNetworks() -> Bool { return false }
    func clearDNSCache() {}
    func registerMyInterface(_ name: String?) {}
    func readWIFIState() -> LibboxWIFIState? { return nil }
    func tailscaleHostname() -> String { return "" }
    func lookupSFTPServer(_ error: NSErrorPointer) -> String { return "" }
    func readSystemSSHHostKey(_ error: NSErrorPointer) -> String { return "" }
    func localDNSTransport() -> LibboxLocalDNSTransport? { return nil }

    func cancelNotification(_ identifier: String?, typeID: Int32, error: NSErrorPointer) -> Bool { return true }
    func checkPlatformShell(_ error: NSErrorPointer) -> Bool { return false }
    func sendNotification(_ notification: LibboxNotification?, error: NSErrorPointer) -> Bool { return true }

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListener?, error: NSErrorPointer) -> Bool { return true }
    func closeDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListener?, error: NSErrorPointer) -> Bool { return true }
    func startNeighborMonitor(_ listener: LibboxNeighborUpdateListener?, error: NSErrorPointer) -> Bool { return true }
    func closeNeighborMonitor(_ listener: LibboxNeighborUpdateListener?, error: NSErrorPointer) -> Bool { return true }

    func createBridge(_ options: LibboxBridgeOptions?, error: NSErrorPointer) -> LibboxBridgeSession? { return nil }
    func getInterfaces(_ error: NSErrorPointer) -> LibboxNetworkInterfaceIterator? { return nil }
    func lookupUser(_ username: String?, error: NSErrorPointer) -> LibboxPlatformUser? { return nil }

    func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32,
                              destinationAddress: String?, destinationPort: Int32,
                              error: NSErrorPointer) -> LibboxConnectionOwner? { return nil }

    func openShellSession(_ user: LibboxPlatformUser?, command: String?,
                          environ: LibboxStringIterator?, term: String?,
                          rows: Int32, cols: Int32,
                          error: NSErrorPointer) -> LibboxShellSession? { return nil }
}
