import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"

    case english = "en"
    case vietnamese = "vi"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .vietnamese: return "Tiếng Việt"
        case .simplifiedChinese: return "简体中文"
        }
    }

    private static let strings: [String: String] = [
        "license.title": "Kích hoạt ứng dụng",
        "license.subtitle": "Nhập mã key để sử dụng đầy đủ tính năng",
        "license.placeholder": "XXXX-XXXX-XXXX-XXXX",
        "license.activate": "Kích hoạt",
        "license.expired": "Đã hết hạn",
        "license.remaining": "Còn %lld ngày %lld giờ",
        "license.activated_success": "Kích hoạt thành công!",
        "license.activated_detail": "Thiết bị: %@ • %@",
        "license.error.not_found": "Key không tồn tại",
        "license.error.revoked": "Key đã bị thu hồi",
        "license.error.expired": "Key đã hết hạn",
        "license.error.device_mismatch": "Key được gán cho thiết bị khác",
        "license.error.device_limit_reached": "Key đã đạt giới hạn thiết bị",
        "license.error.network": "Lỗi kết nối, thử lại sau",
        "maintenance.default_title": "Bảo trì hệ thống",
        "maintenance.default_message": "App đang bảo trì, vui lòng thử lại sau.",
    ]

    func text(_ key: String) -> String {
        Self.strings[key] ?? key
    }

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLanguage.vietnamese
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}
