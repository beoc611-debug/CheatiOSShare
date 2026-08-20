import CryptoKit
import Foundation

enum PatchHubError: Error {
    case invalidResponse
    case checksumMismatch
}

enum PatchHubService {
    static let baseURL = URL(string: "https://patches.cheatiosvip.net")!

    // XOR key = 0x4B
    private static let _t: [UInt8] = [
        0x0F, 0x18, 0x1C, 0x14, 0x28, 0x1D, 0x72, 0x26, 0x13, 0x20, 0x7F, 0x1B, 0x7C, 0x25,
        0x1A, 0x79, 0x14, 0x13, 0x1F, 0x04, 0x00, 0x0E, 0x05, 0x79, 0x7B, 0x79, 0x7D, 0x1D, 0x78
    ]
    private static let _n: [UInt8] = [0x28, 0x3D, 0x64, 0x38, 0x25]
    private static let _r: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x20, 0x2E, 0x32, 0x38, 0x64, 0x39, 0x2E, 0x2F, 0x2E, 0x2E, 0x26]
    private static let _s: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x20, 0x2E, 0x32, 0x38, 0x64, 0x38, 0x3F, 0x2A, 0x3F, 0x3E, 0x38]
    // HMAC signing secret — XOR key 0x4B, decodes to "D5W_hmac_sig_v2_9mQx7nR4pLk8"
    private static let _sk: [UInt8] = [
        0x0F, 0x7E, 0x1C, 0x14, 0x23, 0x26, 0x2A, 0x28, 0x14, 0x38, 0x22, 0x2C, 0x14, 0x3D,
        0x79, 0x14, 0x72, 0x26, 0x1A, 0x33, 0x7C, 0x25, 0x19, 0x7F, 0x3B, 0x07, 0x20, 0x73
    ]

    private static func d(_ b: [UInt8]) -> String {
        String(bytes: b.map { $0 ^ 0x4B }, encoding: .utf8) ?? ""
    }

    static var clientToken: String { d(_t) }
    static var pathNotice: String { d(_n) }
    static var pathRedeem: String { d(_r) }
    static var pathStatus: String { d(_s) }

    static func signKeyRequest(code: String, deviceId: String) -> (ts: String, nonce: String, sig: String) {
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString
        let payload = "\(ts):\(nonce):\(code):\(deviceId)"
        let secret = d(_sk)
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        let sig = Data(mac).map { String(format: "%02x", $0) }.joined()
        return (ts, nonce, sig)
    }

    static func verifyResponse(data: Data, httpResponse: URLResponse) -> Bool {
        guard let http = httpResponse as? HTTPURLResponse,
              let sig = http.value(forHTTPHeaderField: "X-Response-Sig") else { return false }
        let key = SymmetricKey(data: Data(d(_sk).utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        let expected = Data(mac).map { String(format: "%02x", $0) }.joined()
        return expected == sig
    }
}
