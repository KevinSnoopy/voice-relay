import Foundation
import AVFoundation
import COpus

public enum AudioError: Error, CustomStringConvertible {
    case cannotOpen(String)
    case unsupportedFormat(String)
    case resampleFailed
    case opusInit(Int32)
    case opusDecode(Int32)

    public var description: String {
        switch self {
        case .cannotOpen(let path): return "cannot open audio file: \(path)"
        case .unsupportedFormat(let detail): return "unsupported audio format: \(detail)"
        case .resampleFailed: return "resampling to 16 kHz mono failed"
        case .opusInit(let code): return "opus decoder init failed: \(code)"
        case .opusDecode(let code): return "opus decode failed: \(code)"
        }
    }
}

public enum PCM16 {
    public static func decode(_ data: Data) -> [Float] {
        guard data.count >= 2 else { return [] }
        var samples = [Float](repeating: 0, count: data.count / 2)
        data.withUnsafeBytes { raw in
            let pointer = raw.bindMemory(to: Int16.self)
            for i in 0..<samples.count {
                samples[i] = Float(Int16(littleEndian: pointer[i])) / 32768.0
            }
        }
        return samples
    }

    public static func encode(_ samples: [Float]) -> Data {
        var data = Data(capacity: samples.count * 2)
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            var value = Int16(clamped * 32767.0).littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        return data
    }
}

public enum AudioLoader {
    /// Loads any AVFoundation-supported file and converts to 16 kHz mono float32.
    public static func loadMono16k(url: URL) throws -> [Float] {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw AudioError.cannotOpen(url.path)
        }
        let sourceFormat = file.processingFormat
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0 else { return [] }

        if sourceFormat.sampleRate == 16000,
           sourceFormat.channelCount == 1,
           sourceFormat.commonFormat == .pcmFormatFloat32,
           !sourceFormat.isInterleaved {
            let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount)!
            try file.read(into: buffer)
            return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
        }

        let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount)!
        try file.read(into: sourceBuffer)
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw AudioError.resampleFailed
        }
        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio) + 1024
        let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity)!
        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: targetBuffer, error: &conversionError) { _, outStatus in
            if supplied {
                outStatus.pointee = .endOfStream
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }
        guard status != .error, conversionError == nil else {
            throw AudioError.resampleFailed
        }
        guard let channel = targetBuffer.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(targetBuffer.frameLength)))
    }
}

/// Rolling 16 kHz mono float buffer with a hard 2 second cap (docs/02 §7).
public final class PCMStreamBuffer {
    public let sampleRate: Int
    public let capacitySamples: Int
    private var samples: [Float] = []
    public private(set) var overflowCount = 0

    public init(sampleRate: Int = 16000, capacitySeconds: Double = 2.0) {
        self.sampleRate = sampleRate
        self.capacitySamples = Int(Double(sampleRate) * capacitySeconds)
        samples.reserveCapacity(capacitySamples)
    }

    public var count: Int { samples.count }
    public var durationSeconds: Double { Double(samples.count) / Double(sampleRate) }

    /// Returns true when the oldest audio had to be dropped.
    @discardableResult
    public func append(_ newSamples: [Float]) -> Bool {
        guard !newSamples.isEmpty else { return false }
        samples.append(contentsOf: newSamples)
        if samples.count > capacitySamples {
            let drop = samples.count - capacitySamples
            samples.removeFirst(drop)
            overflowCount += 1
            return true
        }
        return false
    }

    public func takeAll() -> [Float] {
        let result = samples
        samples.removeAll(keepingCapacity: true)
        return result
    }

    public func reset() {
        samples.removeAll(keepingCapacity: true)
        overflowCount = 0
    }

    public var rootMeanSquare: Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples { sum += sample * sample }
        return sqrt(sum / Float(samples.count))
    }
}

public final class OpusStreamDecoder {
    private var decoder: OpaquePointer?

    public init(sampleRate: Int32 = 16000, channels: Int32 = 1) throws {
        var error: Int32 = 0
        decoder = opus_decoder_create(sampleRate, channels, &error)
        guard error == OPUS_OK, decoder != nil else {
            throw AudioError.opusInit(error)
        }
    }

    deinit {
        if let decoder { opus_decoder_destroy(decoder) }
    }

    public func decode(_ packet: Data) throws -> [Float] {
        guard let decoder else { throw AudioError.opusDecode(OPUS_INVALID_STATE) }
        let maxSamples: Int32 = 5760
        var output = [Float](repeating: 0, count: Int(maxSamples))
        let decoded: Int32 = packet.withUnsafeBytes { raw in
            let pointer = raw.bindMemory(to: UInt8.self).baseAddress
            return opus_decode_float(decoder, pointer, Int32(packet.count), &output, maxSamples, 0)
        }
        guard decoded >= 0 else { throw AudioError.opusDecode(decoded) }
        return Array(output.prefix(Int(decoded)))
    }
}
