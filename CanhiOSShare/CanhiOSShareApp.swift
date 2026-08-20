import SwiftUI

@main
struct CheatiOSShareApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var licenseGate = LicenseGateStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(licenseGate)
                .environment(\.appLanguage, .vietnamese)
                .preferredColorScheme(.dark)
        }
    }
}
