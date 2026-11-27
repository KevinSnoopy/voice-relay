import Foundation
import AppKit
import VoiceRelayCore

final class Daemon: RelayServerDelegate {
    private let server: RelayServer

    init(server: RelayServer) {
        self.server = server
    }

    func relayServer(_ server: RelayServer, didChange snapshot: RelaySnapshot) {
        if snapshot.connected {
            print("[状态] 已连接 \(snapshot.clientName ?? "") · 后端 \(snapshot.backend) · 模型 \(snapshot.model)")
        } else if let error = snapshot.lastError {
            print("[状态] 未连接 · \(error)")
        } else {
            print("[状态] 等待手机连接 · 端口 \(snapshot.port)")
        }
    }

    func relayServer(_ server: RelayServer, didDeliver result: DeliveredText) {
        let payload: [String: Any] = [
            "ok": result.ok,
            "path": result.path,
            "reason": result.reason ?? "",
            "ms": result.totalMs,
            "asr_ms": result.asrMs,
            "inject_ms": result.injectMs,
            "len": result.charCount,
            "app": result.appName,
            "bundle": result.bundleId,
            "text": result.text,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let line = String(data: data, encoding: .utf8) {
            print("DELIVERED \(line)")
            fflush(stdout)
        }
    }

    func relayServer(_ server: RelayServer, didFail code: Int, message: String) {
        print("[错误] 0x\(String(code, radix: 16)) \(message)")
        fflush(stdout)
    }
}

struct Options {
    var port: Int?
    var pairingCode: String?
    var modelDirectory: String?
    var language = "zh"
    var noITN = false
    var quiet = false

    static func parse() -> Options {
        var options = Options()
        var args = Array(CommandLine.arguments.dropFirst())
        while !args.isEmpty {
            let arg = args.removeFirst()
            switch arg {
            case "--port": options.port = Int(args.first ?? ""); if !args.isEmpty { args.removeFirst() }
            case "--pairing-code": options.pairingCode = args.first; if !args.isEmpty { args.removeFirst() }
            case "--model-dir": options.modelDirectory = args.first; if !args.isEmpty { args.removeFirst() }
            case "--language": options.language = args.first ?? "zh"; if !args.isEmpty { args.removeFirst() }
            case "--no-itn": options.noITN = true
            case "--devices": break
            case "--quiet": options.quiet = true
            case "--help", "-h":
                print("用法: voicerelayd [--port 8787] [--pairing-code 123456] [--model-dir PATH] [--language zh] [--no-itn]")
                exit(0)
            default:
                print("忽略未知参数 \(arg)")
            }
        }
        return options
    }
}

let options = Options.parse()
if CommandLine.arguments.contains("--devices") {
    for device in VirtualMicSink.availableDevices() {
        print("\(device.id)\t\(device.name)")
    }
    exit(0)
}
var settings = AppSettings.load()
if let port = options.port { settings.port = port }
if !options.quiet {
    print("VoiceRelay 守护进程")
    print("模型目录: \(ASRModelLocator.modelsDirectory.path)")
}

let engine: ASREngine
do {
    let modelURL = options.modelDirectory.map { URL(fileURLWithPath: $0) }
    let loaded = try SherpaSenseVoiceEngine(
        modelDirectory: modelURL,
        language: options.language,
        useITN: !options.noITN
    )
    engine = loaded
    if !options.quiet {
        print("模型已加载: \(loaded.modelLabel)")
    }
} catch {
    print("[警告] 模型未加载: \(error)")
    engine = UnavailableASREngine(reason: String(describing: error))
}

let pairing = PairingStore(fixedCode: options.pairingCode, persist: options.pairingCode == nil)
let server = RelayServer(settings: settings, asr: engine, pairing: pairing)
let daemon = Daemon(server: server)
server.delegate = daemon

do {
    try server.start()
} catch {
    print("[致命] 启动失败: \(error)")
    exit(1)
}

if !options.quiet {
    print("配对码: \(pairing.code)")
    print("二维码内容: \(server.pairingJSON())")
    print("监听: 0.0.0.0:\(settings.port) · 等待连接（Ctrl+C 退出）")
}

let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signalSource.setEventHandler {
    print("\n正在退出…")
    server.stop()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exit(0) }
}
signal(SIGINT, SIG_IGN)
signalSource.resume()

signal(SIGTERM, SIG_IGN)
let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
termSource.setEventHandler {
    server.stop()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exit(0) }
}
termSource.resume()

RunLoop.main.run()
