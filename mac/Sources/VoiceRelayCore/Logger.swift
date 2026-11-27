import Foundation

public final class RelayLog {
    public static let shared = RelayLog()

    private let queue = DispatchQueue(label: "com.voicerelay.log")
    private let directory: URL
    private let formatter: ISO8601DateFormatter
    private var fileHandle: FileHandle?
    private var openDay: String?

    public init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/VoiceRelay", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = formatter
    }

    public var directoryURL: URL { directory }

    public func event(_ name: String, _ fields: [String: Any] = [:]) {
        let timestamp = formatter.string(from: Date())
        queue.async { [weak self] in
            guard let self else { return }
            var record = fields
            record["ts"] = timestamp
            record["event"] = name
            guard let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) else { return }
            self.write(data + Data([0x0A]))
        }
    }

    private func write(_ data: Data) {
        let day = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        if openDay != day || fileHandle == nil {
            fileHandle?.closeFile()
            let url = directory.appendingPathComponent("\(day).log")
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            fileHandle = try? FileHandle(forWritingTo: url)
            fileHandle?.seekToEndOfFile()
            openDay = day
            pruneOldLogs()
        }
        fileHandle?.write(data)
    }

    private func pruneOldLogs() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-3 * 24 * 3600)
        for file in files where file.pathExtension == "log" {
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            if date < cutoff { try? FileManager.default.removeItem(at: file) }
        }
    }
}
