import Foundation

/// Persists whether the floating quick-access gear is enabled and which game it points at, so
/// both survive an app relaunch exactly as the user left them.
@MainActor
final class SmartModeStore: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }
    @Published var selectedGameID: String? {
        didSet { UserDefaults.standard.set(selectedGameID, forKey: Self.gameKey) }
    }

    private static let enabledKey = "smartMode.enabled"
    private static let gameKey = "smartMode.selectedGameID"

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        selectedGameID = UserDefaults.standard.string(forKey: Self.gameKey)
    }
}
