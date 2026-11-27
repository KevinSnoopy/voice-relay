import Foundation
import Darwin
import VoiceRelayCore

struct Options {
    var host = "127.0.0.1"
    var port = 8787
    var code = "000000"
    var wav: String?
    var say: String?
    var timeout = 15
    var name = "模拟手机"

    static func parse() -> Options {
        var options = Options()
        var args = Array(CommandLine.arguments.dropFirst())
        while !args.isEmpty {
            let arg = args.removeFirst()
            switch arg {
            case "--host": options.host = args.first ?? options.host; if !args.isEmpty { args.removeFirst() }
            case "--port": options.port = Int(args.first ?? "") ?? options.port; if !args.isEmpty { args.removeFirst() }
            case "--code": options.code = args.first ?? options.code; if !args.isEmpty { args.removeFirst() }
            case "--wav": options.wav = args.first; if !args.isEmpty { args.removeFirst() }
            case "--say": options.say = args.first; if !args.isEmpty { args.removeFirst() }
            case "--timeout": options.timeout = Int(args.first ?? "") ?? options.timeout; if !args.isEmpty { args.removeFirst() }
            case "--name": options.name = args.first ?? options.name; if !args.isEmpty { args.removeFirst() }
            case "--help", "-h":
                print("""
                用法: vrphone --code 123456 (--wav FILE | --say "一句话") [--host 127.0.0.1] [--port 8787]
                说明: 以手机端身份走完整协议，把 WAV（自动转 16k 单声道）发给 Mac，并打印 RESULT。
                """)
                exit(0)
            default:
                break
            }
        }
        return options
    }
}

enum PhoneError: Error, CustomStringConvertible {
    case socket(String)
    case connect(String)
    case timeout
    case remote(String)
    case audio(String)

    var description: String {
        switch self {
        case .socket(let detail): return "socket: \(detail)"
        case .connect(let detail): return "connect: \(detail)"
        case .timeout: return "timeout"
        case .remote(let detail): return "remote: \(detail)"
        case .audio(let detail): return "audio: \(detail)"
        }
    }
}

final class PhoneClient {
    private var fd: Int32 = -1
    private var decoder = FrameDecoder()
    private let timeout: Int

    init(timeout: Int) {
        self.timeout = timeout
    }

    deinit {
        if fd >= 0 { close(fd) }
    }

    func connect(host: String, port: Int) throws {
        fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw PhoneError.socket(String(cString: strerror(errno))) }
        var tv = timeval(tv_sec: timeout, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(port).bigEndian)
        guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
            throw PhoneError.connect("invalid host \(host)")
        }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else { throw PhoneError.connect(String(cString: strerror(errno))) }
    }

    func send(_ frame: Frame) throws {
        let data = frame.encoded()
        try data.withUnsafeBytes { raw in
            var offset = 0
            let base = raw.baseAddress!
            while offset < raw.count {
                let written = Darwin.write(fd, base.advanced(by: offset), raw.count - offset)
                if written <= 0 { throw PhoneError.socket(String(cString: strerror(errno))) }
                offset += written
            }
        }
    }

    func readFrames() throws -> [Frame] {
        var buffer = [UInt8](repeating: 0, count: 8192)
        let count = Darwin.read(fd, &buffer, buffer.count)
        if count < 0 {
            if errno == EAGAIN || errno == EWOULDBLOCK { throw PhoneError.timeout }
            throw PhoneError.socket(String(cString: strerror(errno)))
        }
        if count == 0 { throw PhoneError.remote("connection closed") }
        return try decoder.append(Data(buffer[0..<count]))
    }

    func waitFor(_ type: MessageType) throws -> Frame {
        let deadline = Date().addingTimeInterval(Double(timeout))
        while Date() < deadline {
            let frames = try readFrames()
            for frame in frames {
                if frame.type == .error {
                    let error = try? JSONMessage.decode(ErrorMessage.self, from: frame.payload)
                    throw PhoneError.remote("0x\(String(error?.code ?? 0, radix: 16)) \(error?.message ?? "error")")
                }
                if frame.type == type { return frame }
            }
        }
        throw PhoneError.timeout
    }
}

func makeWavFromSpeech(_ text: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("voicerelay-phone", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let aiff = directory.appendingPathComponent("say.aiff")
    let wav = directory.appendingPathComponent("say.wav")
    let say = Process()
    say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    say.arguments = ["-v", "Tingting", "-o", aiff.path, text]
    try say.run()
    say.waitUntilExit()
    guard say.terminationStatus == 0 else { throw PhoneError.audio("say failed") }
    let convert = Process()
    convert.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
    convert.arguments = ["-f", "WAVE", "-d", "LEI16@16000", "-c", "1", aiff.path, wav.path]
    try convert.run()
    convert.waitUntilExit()
    guard convert.terminationStatus == 0 else { throw PhoneError.audio("afconvert failed") }
    return wav
}

let options = Options.parse()
let wavURL: URL
do {
    if let sayText = options.say {
        wavURL = try makeWavFromSpeech(sayText)
    } else if let path = options.wav {
        wavURL = URL(fileURLWithPath: path)
    } else {
        print("缺少 --wav 或 --say，见 --help")
        exit(2)
    }
} catch {
    print("准备音频失败: \(error)")
    exit(2)
}

let samples: [Float]
do {
    samples = try AudioLoader.loadMono16k(url: wavURL)
} catch {
    print("读取音频失败: \(error)")
    exit(2)
}
guard !samples.isEmpty else {
    print("音频为空")
    exit(2)
}

let client = PhoneClient(timeout: options.timeout)
do {
    try client.connect(host: options.host, port: options.port)
    let mid = "sim-" + UUID().uuidString.prefix(8)
    let hello = HelloMessage(client: "vrphone/1.0", mid: String(mid), name: options.name)
    try client.send(Frame(type: .hello, payload: try JSONMessage.encode(hello)))
    let ackFrame = try client.waitFor(.helloAck)
    let ack = try JSONMessage.decode(HelloAckMessage.self, from: ackFrame.payload)
    guard let challenge = Data(base64Encoded: ack.challenge) else {
        throw PhoneError.remote("bad challenge")
    }
    let key = RelayCrypto.hkdfSHA256(
        ikm: Data(options.code.utf8),
        salt: Data(ack.mid.utf8),
        info: Data("VoiceRelay-Pairing-v1".utf8),
        outputCount: 32
    )
    let mac = RelayCrypto.hmacSHA256(key: key, message: challenge)
    try client.send(Frame(type: .auth, payload: mac))
    _ = try client.waitFor(.authOK)
    print("已连接 \(ack.name) · 后端 \(ack.backend) · 模型 \(ack.model)")

    try client.send(Frame(type: .streamStart, payload: try JSONMessage.encode(StreamStartMessage(sr: 16000, ch: 1, codec: "pcm16"))))
    let frameSamples = 640 // 40 ms
    var sent = 0
    var offset = 0
    while offset < samples.count {
        let end = min(offset + frameSamples, samples.count)
        var payload = Data()
        var seq = UInt16(sent & 0xFFFF).littleEndian
        withUnsafeBytes(of: &seq) { payload.append(contentsOf: $0) }
        var timestamp = UInt32(sent * 40).littleEndian
        withUnsafeBytes(of: &timestamp) { payload.append(contentsOf: $0) }
        payload.append(PCM16.encode(Array(samples[offset..<end])))
        try client.send(Frame(type: .audio, payload: payload, seq: UInt8(sent & 0x3F)))
        offset = end
        sent += 1
        usleep(2000)
    }
    try client.send(Frame(type: .streamStop, payload: try JSONMessage.encode(StreamStopMessage(n: sent))))
    let resultFrame = try client.waitFor(.result)
    let result = try JSONMessage.decode(ResultMessage.self, from: resultFrame.payload)
    let summary: [String: Any] = [
        "ok": result.ok,
        "text": result.text,
        "len": result.len,
        "ms": result.ms,
        "asr_ms": result.asrMs ?? 0,
        "inject_ms": result.injectMs ?? 0,
        "path": result.path ?? "",
        "reason": result.reason ?? "",
        "packets": sent,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys, .prettyPrinted]),
       let text = String(data: data, encoding: .utf8) {
        print(text)
    }
    exit(result.text.isEmpty ? 1 : 0)
} catch {
    print("失败: \(error)")
    exit(1)
}
