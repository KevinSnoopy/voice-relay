import Foundation

/// Pairing code and long-term device keys.
/// First connection derives a key from the 6-digit code, the key is stored in Keychain.
public final class PairingStore {
    public private(set) var code: String
    public let mid: String
    private let persist: Bool
    private var keys: [String: Data]

    private static let keysAccount = "paired-device-keys"
    private static let midKey = "VoiceRelayMacMID"
    private static let codeKey = "VoiceRelayPairingCode"

    public init(fixedCode: String? = nil, persist: Bool = true) {
        self.persist = persist
        if let existing = UserDefaults.standard.string(forKey: Self.midKey) {
            self.mid = existing
        } else {
            let generated = RelayCrypto.randomBytes(8).map { String(format: "%02x", $0) }.joined()
            self.mid = generated
            if persist { UserDefaults.standard.set(generated, forKey: Self.midKey) }
        }
        if let fixedCode {
            self.code = fixedCode
        } else if persist, let stored = UserDefaults.standard.string(forKey: Self.codeKey) {
            self.code = stored
        } else {
            self.code = String(format: "%06d", Int.random(in: 0...999999))
            if persist { UserDefaults.standard.set(self.code, forKey: Self.codeKey) }
        }

        if persist, let blob = try? Data(contentsOf: Self.keysFile),
           let decoded = try? JSONDecoder().decode([String: String].self, from: blob) {
            self.keys = decoded.compactMapValues { Data(base64Encoded: $0) }
        } else {
            self.keys = [:]
        }
    }

    public func rotateCode() {
        code = String(format: "%06d", Int.random(in: 0...999999))
        guard persist else { return }
        UserDefaults.standard.set(code, forKey: Self.codeKey)
        // Old code no longer authorizes new pairings; stored device keys stay valid.
    }

    public func derivedKey(from code: String) -> Data {
        RelayCrypto.hkdfSHA256(
            ikm: Data(code.utf8),
            salt: Data(mid.utf8),
            info: Data("VoiceRelay-Pairing-v1".utf8),
            outputCount: 32
        )
    }

    public func key(for deviceMid: String) -> Data? {
        keys[deviceMid]
    }

    /// Verifies AUTH. On success with the current pairing code, remembers the device key.
    public func verify(deviceMid: String, challenge: Data, mac: Data, presentedCode: String? = nil) -> Bool {
        let candidates: [Data]
        if let stored = keys[deviceMid] {
            candidates = [stored]
        } else if let presentedCode, presentedCode == code {
            candidates = [derivedKey(from: presentedCode)]
        } else {
            candidates = [derivedKey(from: code)]
        }
        for key in candidates {
            let expected = RelayCrypto.hmacSHA256(key: key, message: challenge)
            if RelayCrypto.timingSafeEqual(expected, mac) {
                if keys[deviceMid] == nil {
                    keys[deviceMid] = key
                    persistKeys()
                }
                return true
            }
        }
        return false
    }

    public func revoke(deviceMid: String) {
        keys.removeValue(forKey: deviceMid)
        persistKeys()
    }

    public var pairedDeviceCount: Int { keys.count }
    public var pairedDeviceIDs: [String] { keys.keys.sorted() }

    private static var keysFile: URL {
        ASRModelLocator.supportDirectory.appendingPathComponent("paired-devices.json")
    }

    private func persistKeys() {
        guard persist else { return }
        let encoded = keys.mapValues { $0.base64EncodedString() }
        guard let data = try? JSONEncoder().encode(encoded) else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: ASRModelLocator.supportDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.keysFile, options: [.atomic])
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.keysFile.path)
    }
}
