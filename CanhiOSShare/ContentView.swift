import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var netSecurity = NetworkSecurityMonitor()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch appState.phase {
            case .loading:
                LoadingView()
            case .failed(let message):
                ErrorBlockView(message: message)
            case .ready:
                if netSecurity.isVPNActive {
                    VPNBlockView(isVPN: true, onRetry: { netSecurity.refresh() })
                } else if netSecurity.isProxyActive {
                    VPNBlockView(isVPN: false, onRetry: { netSecurity.refresh() })
                } else {
                    HomeView()
                }
            }
        }
        .task {
            netSecurity.start()
            await appState.prepare()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                netSecurity.refresh()
            }
        }
    }
}
