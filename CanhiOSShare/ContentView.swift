import SwiftUI

struct ContentView: View {
    @StateObject private var licenseGate = LicenseGateStore()
    @StateObject private var netSecurity = NetworkSecurityMonitor()
    @State private var isCheckingMaintenance = true
    @State private var maintenanceNotice: MaintenanceNotice?
    @State private var isJailbroken = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if isJailbroken {
                JailbreakBlockView(onRecheck: { isJailbroken = JailbreakDetector.isJailbroken() })
            } else if netSecurity.isVPNActive {
                VPNBlockView(isVPN: true, onRetry: { netSecurity.refresh() })
            } else if netSecurity.isProxyActive {
                VPNBlockView(isVPN: false, onRetry: { netSecurity.refresh() })
            } else if isCheckingMaintenance || licenseGate.isChecking {
                ZStack {
                    TechBackground()
                    ProgressView()
                }
                .preferredColorScheme(.dark)
            } else if let maintenanceNotice {
                MaintenanceView(notice: maintenanceNotice)
            } else if licenseGate.isUnlocked {
                GamesHomeView()
            } else {
                KeyEntryView()
            }
        }
        .environmentObject(licenseGate)
        .task {
            isJailbroken = JailbreakDetector.isJailbroken()
            netSecurity.start()
            async let maintenance: () = checkMaintenance()
            async let license: () = licenseGate.bootstrap()
            _ = await (maintenance, license)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                netSecurity.refresh()
                Task {
                    await checkMaintenance()
                    await licenseGate.revalidateIfNeeded()
                }
            }
        }
    }

    private func checkMaintenance() async {
        if case .maintenance(let notice) = await AnnouncementService.fetchState() {
            maintenanceNotice = notice
        } else {
            maintenanceNotice = nil
        }
        isCheckingMaintenance = false
    }
}
