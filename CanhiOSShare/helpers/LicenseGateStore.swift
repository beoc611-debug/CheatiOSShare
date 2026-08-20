import Foundation
import Security

@MainActor
final class LicenseGateStore: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var isChecking = true
    @Published private(set) var expiresAt: Date?
    @Published private(set) var licenseDevices: [LicenseDeviceEntry] = []
    @Published var errorMessage: String?
    @Published var activationToast: ToastMessage?

    private static let kcService = "com.cheatiosvip.license"
    private static let kcAccount = "key-code"

    private(set) var storedKeyCode: String? {
        get { Self.keychainLoad() }
        set {
            if let value = newValue { Self.keychainSave(value) }
            else { Self.keychainDelete() }
        }
    }

    private static func keychainLoad() -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kcService,
            kSecAttrAccount as String: kcAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ref: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &ref) == errSecSuccess,
              let data = ref as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainSave(_ value: String) {
        let data = Data(value.utf8)
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kcService,
            kSecAttrAccount as String: kcAccount
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(q as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            var item = q; attrs.forEach { item[$0.key] = $0.value }
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    private static func keychainDelete() {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kcService,
            kSecAttrAccount as String: kcAccount
        ]
        SecItemDelete(q as CFDictionary)
    }

    var maskedKeyCode: String {
        guard let code = storedKeyCode else { return "" }
        guard code.count > 8 else { return code }
        return "\(code.prefix(4))••••\(code.suffix(4))"
    }

    func remainingTimeText(language: AppLanguage) -> String {
        guard let expiresAt else { return "" }
        let seconds = expiresAt.timeIntervalSinceNow
        guard seconds > 0 else { return language.text("license.expired") }
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        return language.text("license.remaining", Int64(days), Int64(hours))
    }

    func bootstrap() async {
        isChecking = true
        defer { isChecking = false }
        guard let code = storedKeyCode, !code.isEmpty else {
            isUnlocked = false
            return
        }
        await refreshStatus(code: code)
    }

    func revalidateIfNeeded() async {
        guard isUnlocked, let code = storedKeyCode else { return }
        await refreshStatus(code: code)
    }

    @discardableResult
    func redeem(code rawCode: String) async -> Bool {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        errorMessage = nil
        do {
            let result = try await LicenseKeyService.redeem(
                code: code,
                deviceId: DeviceIdentity.current,
                deviceModel: AppInfo.hardwareDisplayName
            )
            storedKeyCode = code
            expiresAt = result.expiresAt
            licenseDevices = result.devices
            isUnlocked = true
            let language = AppLanguage.vietnamese
            let detail = language.text("license.activated_detail", AppInfo.hardwareDisplayName, remainingTimeText(language: language))
            activationToast = ToastMessage(text: "\(language.text("license.activated_success"))\n\(detail)")
            return true
        } catch let error as LicenseKeyError {
            errorMessage = AppLanguage.vietnamese.text(error.localizationKey)
            return false
        } catch {
            errorMessage = AppLanguage.vietnamese.text(LicenseKeyError.network.localizationKey)
            return false
        }
    }

    func changeKey() {
        storedKeyCode = nil
        expiresAt = nil
        licenseDevices = []
        isUnlocked = false
        errorMessage = nil
    }

    private func refreshStatus(code: String) async {
        do {
            let result = try await LicenseKeyService.status(code: code, deviceId: DeviceIdentity.current)
            expiresAt = result.expiresAt
            licenseDevices = result.devices
            isUnlocked = true
        } catch LicenseKeyError.network {
            // Connectivity issue only — keep whatever unlocked state we already had.
        } catch {
            isUnlocked = false
        }
    }
}
