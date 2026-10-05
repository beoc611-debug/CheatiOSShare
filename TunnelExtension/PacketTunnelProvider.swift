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
        try? server?.closeService()
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
        try server!.startOrReloadService(config, options: nil)

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

private class TunnelPlatform: NSObject, LibboxPlatformInterfaceProtocol {

    unowned let provider: NEPacketTunnelProvider

    init(provider: NEPacketTunnelProvider) { self.provider = provider }

    // openTun is NOT auto-bridged to throws (out param ret0_ prevents it)
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

        if let fd = (provider.packetFlow as AnyObject).value(forKey: "socket.fileDescriptor") as? Int32, fd >= 0 {
            ret0_?.pointee = fd
            return true
        }
        error?.pointee = NSError(domain: "SBTunnel", code: -4, userInfo: [NSLocalizedDescriptionKey: "Cannot obtain TUN fd"])
        return false
    }

    // Renamed methods (compiler told us the correct names)
    func autoDetectControl(_ fd: Int32) throws {}
    func usePlatformAutoDetectControl() -> Bool { return true }
    func send(_ notification: LibboxNotification?) throws {}

    func underNetworkExtension() -> Bool { return true }
    func usePlatformBridge() -> Bool { return false }
    func usePlatformShell() -> Bool { return false }
    func useProcFS() -> Bool { return false }
    func includeAllNetworks() -> Bool { return false }
    func clearDNSCache() {}
    func registerMyInterface(_ name: String?) {}
    func readWIFIState() -> LibboxWIFIState? { return nil }
    func tailscaleHostname() -> String { return "" }
    func localDNSTransport() -> LibboxLocalDNSTransportProtocol? { return nil }

    // _Nonnull String return + NSError** → NOT bridged to throws (non-optional can't signal failure via nil)
    func lookupSFTPServer(_ error: NSErrorPointer) -> String { return "" }
    func readSystemSSHHostKey(_ error: NSErrorPointer) -> String { return "" }

    func cancelNotification(_ identifier: String?, typeID: Int32) throws {}
    func checkPlatformShell() throws { throw NSError(domain: "SBTunnel", code: -5, userInfo: nil) }

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {}
    func closeDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {}
    func startNeighborMonitor(_ listener: LibboxNeighborUpdateListenerProtocol?) throws {}
    func closeNeighborMonitor(_ listener: LibboxNeighborUpdateListenerProtocol?) throws {}

    // Nullable object return + NSError** → ObjC style (keep error: param, no throws)
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
