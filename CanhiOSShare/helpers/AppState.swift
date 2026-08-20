import Foundation

enum StartupPhase {
    case loading
    case ready
    case failed(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var phase: StartupPhase = .loading
    @Published private(set) var virtualRoot: String = ""

    func prepare() async {
        await Task.detached(priority: .userInitiated) {
            MCMFilzaStart()
        }.value

        let root = MCMFilzaVirtualRoot()
        if root.isEmpty {
            phase = .failed("Không thể khởi tạo hệ thống file. Hãy thử cài lại app.")
            return
        }
        virtualRoot = root
        phase = .ready
    }
}
