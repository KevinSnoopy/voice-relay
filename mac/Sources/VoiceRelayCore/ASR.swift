import Foundation
import CSherpaOnnx

public enum ASRState: Equatable {
    case unavailable(String)
    case loading
    case ready
}

public struct ASRResult: Equatable {
    public var text: String
    public var asrMs: Int
    public var audioSeconds: Double
}

public protocol ASREngine: AnyObject {
    var state: ASRState { get }
    var modelLabel: String { get }
    func transcribe(_ samples: [Float], sampleRate: Int) throws -> ASRResult
}

public enum ASRError: Error, CustomStringConvertible {
    case modelMissing(String)
    case createFailed
    case streamFailed
    case emptyAudio

    public var description: String {
        switch self {
        case .modelMissing(let detail): return "model missing: \(detail)"
        case .createFailed: return "cannot create sherpa-onnx recognizer"
        case .streamFailed: return "cannot create offline stream"
        case .emptyAudio: return "no audio to recognize"
        }
    }
}

public final class SherpaSenseVoiceEngine: ASREngine {
    public private(set) var state: ASRState = .unavailable("未加载")
    public let modelLabel: String
    private var recognizer: OpaquePointer?
    private let lock = NSLock()

    public init(
        modelDirectory: URL? = nil,
        numThreads: Int32 = 4,
        language: String = "zh",
        useITN: Bool = true
    ) throws {
        guard let directory = modelDirectory ?? ASRModelLocator.senseVoiceDirectory() else {
            throw ASRError.modelMissing("\(ASRModelLocator.modelsDirectory.path) 下没有 SenseVoice int8 模型")
        }
        let modelPath = directory.appendingPathComponent("model.int8.onnx").path
        let tokensPath = directory.appendingPathComponent("tokens.txt").path
        let fm = FileManager.default
        guard fm.fileExists(atPath: modelPath), fm.fileExists(atPath: tokensPath) else {
            throw ASRError.modelMissing(directory.path)
        }
        modelLabel = "SenseVoice Small (int8)"
        state = .loading

        var config = SherpaOnnxOfflineRecognizerConfig()
        config.feat_config.sample_rate = 16000
        config.feat_config.feature_dim = 80
        config.model_config.num_threads = numThreads
        config.model_config.debug = 0
        config.decoding_method = nil
        config.max_active_paths = 4

        let created: OpaquePointer? = modelPath.withCString { modelC in
            tokensPath.withCString { tokensC in
                language.withCString { languageC in
                    "cpu".withCString { providerC in
                        "greedy_search".withCString { decodingC in
                            config.model_config.sense_voice.model = modelC
                            config.model_config.sense_voice.language = languageC
                            config.model_config.sense_voice.use_itn = useITN ? 1 : 0
                            config.model_config.tokens = tokensC
                            config.model_config.provider = providerC
                            config.decoding_method = decodingC
                            return SherpaOnnxCreateOfflineRecognizer(&config)
                        }
                    }
                }
            }
        }

        guard let created else {
            state = .unavailable("模型加载失败")
            throw ASRError.createFailed
        }
        recognizer = created
        state = .ready
    }

    deinit {
        if let recognizer {
            SherpaOnnxDestroyOfflineRecognizer(recognizer)
        }
    }

    public func transcribe(_ samples: [Float], sampleRate: Int) throws -> ASRResult {
        guard !samples.isEmpty else { throw ASRError.emptyAudio }
        lock.lock()
        defer { lock.unlock() }
        guard let recognizer else { throw ASRError.createFailed }
        guard let stream = SherpaOnnxCreateOfflineStream(recognizer) else { throw ASRError.streamFailed }
        defer { SherpaOnnxDestroyOfflineStream(stream) }

        let started = Date()
        samples.withUnsafeBufferPointer { pointer in
            SherpaOnnxAcceptWaveformOffline(stream, Int32(sampleRate), pointer.baseAddress, Int32(samples.count))
        }
        SherpaOnnxDecodeOfflineStream(recognizer, stream)
        guard let resultPointer = SherpaOnnxGetOfflineStreamResult(stream) else {
            throw ASRError.streamFailed
        }
        let text = resultPointer.pointee.text.map { String(cString: $0) } ?? ""
        SherpaOnnxDestroyOfflineRecognizerResult(resultPointer)
        let elapsed = Int(Date().timeIntervalSince(started) * 1000)
        return ASRResult(text: text, asrMs: elapsed, audioSeconds: Double(samples.count) / Double(sampleRate))
    }
}

public final class UnavailableASREngine: ASREngine {
    public let state: ASRState
    public let modelLabel = "未加载"
    private let reason: String

    public init(reason: String) {
        self.reason = reason
        self.state = .unavailable(reason)
    }

    public func transcribe(_ samples: [Float], sampleRate: Int) throws -> ASRResult {
        throw ASRError.modelMissing(reason)
    }
}
