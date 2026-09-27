import Darwin
import Foundation
import Network

@MainActor
final class NetworkSecurityMonitor: ObservableObject {
    @Published private(set) var isVPNActive = false
    @Published private(set) var isProxyActive = false

    var isBlocked: Bool { isVPNActive || isProxyActive }

    private var pathMonitor: NWPathMonitor?
    private var latestPath: NWPath?

    func start() {
        let m = NWPathMonitor()
        m.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task { @MainActor [self] in
                self.latestPath = path
                self.applyPath(path)
            }
        }
        m.start(queue: DispatchQueue(label: "canh.netsec", qos: .utility))
        pathMonitor = m
    }

    func stop() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    func refresh() {
        if let p = latestPath {
            applyPath(p)
        } else {
            isProxyActive = Self.detectProxy()
        }
    }

    private func applyPath(_ path: NWPath) {
        let pathUsesVPNType = path.usesInterfaceType(.other)
        let tunnelHasIPv4 = Self.tunnelInterfaceHasIPv4()
        isVPNActive   = pathUsesVPNType && tunnelHasIPv4
        isProxyActive = Self.detectProxy()
    }

    private static func tunnelInterfaceHasIPv4() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let head = ifaddr else { return false }
        defer { freeifaddrs(head) }
        var cur: UnsafeMutablePointer<ifaddrs>? = head
        while let node = cur {
            let name = String(cString: node.pointee.ifa_name)
            let isTunnel = name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")
            if isTunnel, let addr = node.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                return true
            }
            cur = node.pointee.ifa_next
        }
        return false
    }

    private static func detectProxy() -> Bool {
        guard let raw = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
              let settings = raw as? [String: Any] else { return false }
        for key in ["HTTPProxy", "HTTPSProxy", "SOCKSProxy"] {
            if let host = settings[key] as? String, !host.isEmpty { return true }
        }
        return false
    }
}
