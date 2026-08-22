import Foundation

struct LicenseDeviceEntry {
    let deviceModel: String?
    let redeemedAt: Date?
}

struct LicenseRedeemResult {
    let redeemedAt: Date
    let durationDays: Int
    let expiresAt: Date
    let devices: [LicenseDeviceEntry]
}

enum LicenseKeyError: Error {
    case notFound
    case revoked
    case expired
    case deviceMismatch
    case deviceLimitReached
    case network

    var localizationKey: String {
        switch self {
        case .notFound: return "license.error.not_found"
        case .revoked: return "license.error.revoked"
        case .expired: return "license.error.expired"
        case .deviceMismatch: return "license.error.device_mismatch"
        case .deviceLimitReached: return "license.error.device_limit_reached"
        case .network: return "license.error.network"
        }
    }
}

enum LicenseKeyService {
    private static let baseURL = PatchHubService.baseURL

    private struct KeyDeviceEntry: Decodable {
        let deviceModel: String?
        let redeemedAt: String?
    }

    private struct KeyResponse: Decodable {
        let ok: Bool
        let error: String?
        let redeemedAt: String?
        let durationDays: Int?
        let expiresAt: String?
        let devices: [KeyDeviceEntry]?
    }

    private static let dateFormatterWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return dateFormatterWithFraction.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    private static func mapError(_ code: String?) -> LicenseKeyError {
        switch code {
        case "not_found": return .notFound
        case "revoked": return .revoked
        case "expired": return .expired
        case "device_mismatch": return .deviceMismatch
        case "device_limit_reached": return .deviceLimitReached
        default: return .network
        }
    }

    private static func result(from response: KeyResponse, statusCode: Int) throws -> LicenseRedeemResult {
        guard statusCode == 200, response.ok,
              let redeemedAt = parseDate(response.redeemedAt),
              let expiresAt = parseDate(response.expiresAt),
              let durationDays = response.durationDays
        else {
            throw mapError(response.error)
        }
        let devices = (response.devices ?? []).map {
            LicenseDeviceEntry(deviceModel: $0.deviceModel, redeemedAt: parseDate($0.redeemedAt))
        }
        return LicenseRedeemResult(redeemedAt: redeemedAt, durationDays: durationDays, expiresAt: expiresAt, devices: devices)
    }

    private static func formBody(_ params: [String: String]) -> Data {
        params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    static func redeem(code: String, deviceId: String, deviceModel: String) async throws -> LicenseRedeemResult {
        var request = URLRequest(url: baseURL.appendingPathComponent(PatchHubService.pathRedeem))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(PatchHubService.clientToken, forHTTPHeaderField: PatchHubService.hAppToken)
        let (ts, nonce, sig) = PatchHubService.signKeyRequest(code: code, deviceId: deviceId)
        request.setValue(ts,    forHTTPHeaderField: PatchHubService.hReqTime)
        request.setValue(nonce, forHTTPHeaderField: PatchHubService.hReqNonce)
        request.setValue(sig,   forHTTPHeaderField: PatchHubService.hReqSig)
        request.httpBody = formBody(["code": code, "deviceId": deviceId, "deviceModel": deviceModel])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LicenseKeyError.network
        }
        guard PatchHubService.verifyResponse(data: data, httpResponse: response) else {
            throw LicenseKeyError.network
        }
        guard let http = response as? HTTPURLResponse,
              let decoded = try? JSONDecoder().decode(KeyResponse.self, from: data) else {
            throw LicenseKeyError.network
        }
        return try result(from: decoded, statusCode: http.statusCode)
    }

    static func status(code: String, deviceId: String) async throws -> LicenseRedeemResult {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(PatchHubService.pathStatus),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "deviceId", value: deviceId)
        ]
        var statusRequest = URLRequest(url: components.url!)
        statusRequest.setValue(PatchHubService.clientToken, forHTTPHeaderField: PatchHubService.hAppToken)
        let (ts, nonce, sig) = PatchHubService.signKeyRequest(code: code, deviceId: deviceId)
        statusRequest.setValue(ts,    forHTTPHeaderField: PatchHubService.hReqTime)
        statusRequest.setValue(nonce, forHTTPHeaderField: PatchHubService.hReqNonce)
        statusRequest.setValue(sig,   forHTTPHeaderField: PatchHubService.hReqSig)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: statusRequest)
        } catch {
            throw LicenseKeyError.network
        }
        guard PatchHubService.verifyResponse(data: data, httpResponse: response) else {
            throw LicenseKeyError.network
        }
        guard let http = response as? HTTPURLResponse,
              let decoded = try? JSONDecoder().decode(KeyResponse.self, from: data) else {
            throw LicenseKeyError.network
        }
        return try result(from: decoded, statusCode: http.statusCode)
    }
}
