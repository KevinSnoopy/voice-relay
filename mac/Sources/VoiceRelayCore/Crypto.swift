import Foundation
import CryptoKit

public enum RelayCrypto {
    public static func randomBytes(_ count: Int) -> Data {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        return data
    }

    public static func hmacSHA256(key: Data, message: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        return Data(HMAC<SHA256>.authenticationCode(for: message, using: symmetricKey))
    }

    /// RFC 5869 HKDF-SHA256.
    public static func hkdfSHA256(ikm: Data, salt: Data, info: Data, outputCount: Int = 32) -> Data {
        let effectiveSalt = salt.isEmpty ? Data(repeating: 0, count: 32) : salt
        let prk = hmacSHA256(key: effectiveSalt, message: ikm)
        var output = Data()
        var previous = Data()
        var counter: UInt8 = 1
        while output.count < outputCount {
            previous = hmacSHA256(key: prk, message: previous + info + Data([counter]))
            output.append(previous)
            counter = counter &+ 1
        }
        return output.prefix(outputCount)
    }

    public static func timingSafeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (a, b) in zip(lhs, rhs) { difference |= a ^ b }
        return difference == 0
    }
}

public enum Keychain {
    private static let service = "com.voicerelay.pairing"

    public static func save(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(insert as CFDictionary, nil)
    }

    public static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    public static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
