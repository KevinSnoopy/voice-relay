import Foundation

public enum ModelInstallError: LocalizedError {
    case httpStatus(Int)
    case downloadMissing
    case extract(String)
    case verify

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code): return "下载失败（HTTP \(code)）"
        case .downloadMissing: return "下载完成但没有拿到文件"
        case .extract(let detail): return "解压失败：\(detail)"
        case .verify: return "解压后没有找到 model.int8.onnx / tokens.txt"
        }
    }
}

/// Downloads the SenseVoice int8 model from the sherpa-onnx release page and
/// unpacks it into `~/Library/Application Support/VoiceRelay/models/`.
///
/// The app intentionally does not ship model weights: they are licensed
/// separately by their authors. Downloading them on first launch keeps the
/// installer small and the licensing story clean.
public final class ModelInstaller: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    public static let modelFolderName = "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"
    public static let downloadURL = URL(
        string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/\(modelFolderName).tar.bz2"
    )!
    public static let approximateSize = "155 MB"

    private let lock = NSLock()
    private var progressHandler: ((Double, String) -> Void)?
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    private var downloadedFile: URL?

    /// Downloads and installs the model. The returned URL is the model directory.
    public func install(progress: @escaping (Double, String) -> Void) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            self.progressHandler = progress
            lock.unlock()

            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 60 * 30
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            lock.lock()
            self.session = session
            lock.unlock()
            session.downloadTask(with: Self.downloadURL).resume()
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let fraction = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        let written = Double(totalBytesWritten) / 1_048_576
        let message = totalBytesExpectedToWrite > 0
            ? String(format: "下载中 %.0f / %.0f MB", written, Double(totalBytesExpectedToWrite) / 1_048_576)
            : String(format: "下载中 %.0f MB", written)
        lock.lock()
        let handler = progressHandler
        lock.unlock()
        handler?(min(max(fraction, 0), 1), message)
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicerelay-model-\(UUID().uuidString).tar.bz2")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            lock.lock()
            downloadedFile = destination
            lock.unlock()
        } catch {
            lock.lock()
            downloadedFile = nil
            lock.unlock()
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        session.finishTasksAndInvalidate()

        if let error {
            finish(.failure(error))
            return
        }
        if let http = task.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            finish(.failure(ModelInstallError.httpStatus(http.statusCode)))
            return
        }

        lock.lock()
        let archive = downloadedFile
        downloadedFile = nil
        lock.unlock()

        guard let archive else {
            finish(.failure(ModelInstallError.downloadMissing))
            return
        }

        lock.lock()
        let handler = progressHandler
        lock.unlock()
        handler?(1, "解压中…")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let directory = try Self.extract(archive)
                self.finish(.success(directory))
            } catch {
                try? FileManager.default.removeItem(at: archive)
                self.finish(.failure(error))
            }
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        self.progressHandler = nil
        self.session = nil
        lock.unlock()
        continuation?.resume(with: result)
    }

    private static func extract(_ archive: URL) throws -> URL {
        let fileManager = FileManager.default
        let models = ASRModelLocator.modelsDirectory
        try fileManager.createDirectory(at: models, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xjf", archive.path, "-C", models.path]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        try? fileManager.removeItem(at: archive)

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "tar 退出码 \(process.terminationStatus)"
            throw ModelInstallError.extract(message)
        }
        guard let directory = ASRModelLocator.senseVoiceDirectory() else {
            throw ModelInstallError.verify
        }
        return directory
    }
}
