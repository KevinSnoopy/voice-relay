import Foundation

public struct AppSettings: Codable, Equatable {
    public var port: Int = 8787
    public var backend: String = "A"
    public var launchAtLogin: Bool = false
    public var showOverlay: Bool = true
    public var echoReturn: Bool = false
    public var focusTabFallback: Bool = true
    public var maxRecordSeconds: Int = 60
    public var sensitivity: Int = 62
    public var releaseDelayMs: Int = 180
    public var asrLanguage: String = "zh"
    public var useITN: Bool = true
    public var showPairingOnLaunch: Bool = true
    public var recentTextLimit: Int = 3
    public var bleEnabled: Bool = false
    /// Off by default: direct AX/Unicode insertion only. Enabling allows a temporary clipboard paste.
    public var allowPasteInjection: Bool = false
    public var virtualDeviceName: String = "BlackHole 2ch"

    public init() {}

    public static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "VoiceRelaySettings"),
              let value = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return value
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "VoiceRelaySettings")
        }
    }
}

public enum ASRModelLocator {
    public static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/VoiceRelay", isDirectory: true)
    }

    public static var modelsDirectory: URL {
        supportDirectory.appendingPathComponent("models", isDirectory: true)
    }

    /// Finds the SenseVoice int8 model bundle downloaded by scripts/download-models.sh.
    public static func senseVoiceDirectory() -> URL? {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil) else { return nil }
        let candidates = entries.filter {
            $0.lastPathComponent.contains("sense-voice") && $0.hasDirectoryPath
        }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for directory in candidates {
            let model = directory.appendingPathComponent("model.int8.onnx")
            let tokens = directory.appendingPathComponent("tokens.txt")
            if fm.fileExists(atPath: model.path) && fm.fileExists(atPath: tokens.path) {
                return directory
            }
        }
        return nil
    }
}
