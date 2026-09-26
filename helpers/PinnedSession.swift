import CryptoKit
import Foundation
import Security

private final class PinningDelegate: NSObject, URLSessionDelegate {
    // RSA-2048 SubjectPublicKeyInfo ASN.1 wrapper (prepended to raw key bytes to form SPKI)
    private static let rsa2048Hdr: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09,
        0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
        0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ]

    // XOR-0x4B encoded SPKI SHA-256 hash of patches.cheatiosvip.net leaf public key
    // Decoded base64: CYULASK4BbehwbvLv2EX6/IyqS5o8sUcjv7s9hEaaYk=
    private static let _ph: [UInt8] = [
        0x08, 0x12, 0x1E, 0x07, 0x0A, 0x18, 0x00, 0x7F,
        0x09, 0x29, 0x2E, 0x23, 0x3C, 0x29, 0x3D, 0x07,
        0x3D, 0x79, 0x0E, 0x13, 0x7D, 0x64, 0x02, 0x32,
        0x3A, 0x18, 0x7E, 0x24, 0x73, 0x38, 0x1E, 0x28,
        0x21, 0x3D, 0x7C, 0x38, 0x72, 0x23, 0x0E, 0x2A,
        0x2A, 0x12, 0x20, 0x76
    ]

    private static let pinnedHash: Data = {
        let b64 = String(bytes: _ph.map { $0 ^ 0x4B }, encoding: .utf8) ?? ""
        return Data(base64Encoded: b64) ?? Data()
    }()

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition,
                                                   URLCredential?) -> Void) {
        // Only pin connections to our own server; let everything else use default trust
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host.hasSuffix("patches.cheatiosvip.net"),
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var cfError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &cfError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] ?? []
        guard let leaf = chain.first,
              let pubKey = SecCertificateCopyKey(leaf),
              let rawKey = SecKeyCopyExternalRepresentation(pubKey, nil) as Data?
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Build SPKI: prepend RSA-2048 header to raw key bytes, then SHA-256
        var spki = Data(Self.rsa2048Hdr)
        spki.append(rawKey)
        let digest = Data(SHA256.hash(data: spki))

        if digest == Self.pinnedHash {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

enum PinnedSession {
    static let shared: URLSession = {
        URLSession(configuration: .default,
                   delegate: PinningDelegate(),
                   delegateQueue: nil)
    }()
}
