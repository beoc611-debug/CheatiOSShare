import SwiftUI

struct ContentView: View {
    @StateObject private var licenseGate = LicenseGateStore()
    @StateObject private var netSecurity = NetworkSecurityMonitor()
    @State private var isCheckingMaintenance = true
    @State private var maintenanceNotice: MaintenanceNotice?
    @State private var blockingAnnouncement: Announcement?
    @State private var isTampered = false
    @State private var isJailbroken = false
    @State private var showSplash = true
    @AppStorage("shown_announcement_ids") private var shownIDsRaw = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            mainContent
            if let ann = blockingAnnouncement {
                AnnouncementBlockView(announcement: ann)
                    .zIndex(998)
                    .transition(.opacity)
            }
            if showSplash {
                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
                .zIndex(999)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .animation(.easeInOut(duration: 0.3), value: blockingAnnouncement == nil)
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if isTampered {
                TamperBlockView()
            } else if isJailbroken {
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
            } else if licenseGate.isUnlocked && licenseGate.isReallyUnlocked {
                GamesHomeView()
            } else {
                KeyEntryView()
            }
        }
        .environmentObject(licenseGate)
        .task {
            isJailbroken = JailbreakDetector.isJailbroken()
            netSecurity.start()
            // Tamper scan: collect all non-system dylibs and send to server.
            // Server compares against IPA baseline — bans device if extra dylibs found.
            let scan = TamperDetector.scan()
            if scan.hasLocalSuspicion || scan.hasInjectedBinary {
                // Fire report async then crash — no warning screen shown
                Task { await TamperDetector.report(scan: scan, reason: "dylib_injection") }
                try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s for report to go out
                abort()
            }
            let serverSaysTampered = await TamperDetector.report(scan: scan, reason: "startup_check")
            if serverSaysTampered {
                Task.detached { try? await Task.sleep(nanoseconds: 300_000_000); abort() }
                return
            }
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
        switch await AnnouncementService.fetchState() {
        case .maintenance(let notice):
            maintenanceNotice = notice
            blockingAnnouncement = nil
        case .announcement(let ann):
            maintenanceNotice = nil
            var shownIDs = Set(shownIDsRaw.split(separator: ",").map(String.init))
            if !shownIDs.contains(ann.id) {
                shownIDs.insert(ann.id)
                shownIDsRaw = shownIDs.joined(separator: ",")
                blockingAnnouncement = ann
            }
        case .none:
            maintenanceNotice = nil
            blockingAnnouncement = nil
        }
        isCheckingMaintenance = false
    }
}
