import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @StateObject private var netSecurity = NetworkSecurityMonitor()
    @StateObject private var noticeHolder = NoticeStateHolder()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isJailbroken = false

    var body: some View {
        Group {
            if isJailbroken {
                JailbreakBlockView(onRecheck: {
                    isJailbroken = JailbreakDetector.isJailbroken()
                })
            } else if netSecurity.isBlocked {
                VPNBlockView(isVPN: netSecurity.isVPNActive, onRetry: { netSecurity.refresh() })
            } else {
                switch appState.phase {
                case .loading:
                    LoadingView()
                case .failed(let message):
                    ErrorBlockView(message: message)
                case .ready:
                    if case .maintenance(let notice) = noticeHolder.state {
                        MaintenanceView(notice: notice)
                    } else if licenseGate.isChecking {
                        LoadingView()
                    } else if !licenseGate.isUnlocked {
                        KeyEntryView()
                    } else {
                        HomeView()
                    }
                }
            }
        }
        .task {
            isJailbroken = JailbreakDetector.isJailbroken()
            netSecurity.start()
            await appState.prepare()
            await licenseGate.bootstrap()
            await checkMaintenance()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                netSecurity.refresh()
                Task {
                    await licenseGate.revalidateIfNeeded()
                    await checkMaintenance()
                }
            }
        }
        .toast($licenseGate.activationToast)
    }

    private func checkMaintenance() async {
        noticeHolder.state = await AnnouncementService.fetchState()
    }
}

@MainActor
private final class NoticeStateHolder: ObservableObject {
    @Published var state: RemoteNoticeState = .none
}
