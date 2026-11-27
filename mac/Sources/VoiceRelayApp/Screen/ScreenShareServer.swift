import Foundation
import Network
import ScreenCaptureKit
import VoiceRelayCore

/// Dedicated screen-control channel. It runs on port+1 and uses newline-delimited
/// JSON, so the existing 4-bit/16-bit protocol and its 8 KB frame limit are untouched.
/// Video itself goes through WebRTC/DTLS-SRTP; this channel carries auth + signaling.
final class ScreenShareServer {
    private let port: UInt16
    private let pairing: PairingStore
    private let log: RelayLog
    private let queue = DispatchQueue(label: "com.voicerelay.screen.server")
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: ScreenClient] = [:]
    private var started = false
    private var focusObserver: NSObjectProtocol?

    var onActiveChange: ((Bool) -> Void)?

    init(port: UInt16, pairing: PairingStore, log: RelayLog) {
        self.port = port
        self.pairing = pairing
        self.log = log
        self.focusObserver = NotificationCenter.default.addObserver(
            forName: .voiceRelayFocusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncAllSessionsToFocus()
        }
    }

    deinit {
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
    }

    private func syncAllSessionsToFocus() {
        for client in clients.values {
            client.session?.syncToFocus()
        }
    }

    func start() throws {
        guard !started else { return }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw RelayServerError.invalidPort(Int(port))
        }
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = false
        let listener = try NWListener(using: parameters, on: nwPort)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.log.event("screen_server_ready", ["port": Int(self.port)])
            case .failed(let error):
                self.log.event("screen_server_failed", ["error": String(describing: error)])
            default:
                break
            }
        }
        self.listener = listener
        listener.start(queue: queue)
        started = true
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.listener?.cancel()
            self.listener = nil
            for client in self.clients.values {
                client.session?.stop()
                client.connection.cancel()
            }
            self.clients.removeAll()
            self.started = false
        }
    }

    private func accept(_ connection: NWConnection) {
        let client = ScreenClient(connection: connection)
        clients[ObjectIdentifier(client)] = client
        log.event("screen_client_connected", ["id": client.id.uuidString])
        connection.stateUpdateHandler = { [weak self, weak client] state in
            guard let self, let client else { return }
            switch state {
            case .ready:
                self.receive(on: client)
            case .failed, .cancelled:
                self.drop(client)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receive(on client: ScreenClient) {
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self, weak client] data, _, isComplete, error in
            guard let self, let client else { return }
            if let data, !data.isEmpty {
                client.buffer.append(data)
                self.consumeLines(client)
            }
            if isComplete || error != nil {
                self.drop(client)
                return
            }
            self.receive(on: client)
        }
    }

    private func consumeLines(_ client: ScreenClient) {
        while let newline = client.buffer.firstIndex(of: 0x0A) {
            let line = client.buffer[client.buffer.startIndex..<newline]
            client.buffer.removeSubrange(client.buffer.startIndex...newline)
            guard !line.isEmpty else { continue }
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else {
                client.send(["op": "error", "code": "bad_json", "message": "消息格式错误"])
                continue
            }
            DispatchQueue.main.async { [weak self] in
                self?.handle(object, from: client)
            }
        }
    }

    private func handle(_ object: [String: Any], from client: ScreenClient) {
        let op = object["op"] as? String ?? ""
        switch op {
        case "hello":
            handleHello(object, client)
        case "auth":
            handleAuth(object, client)
        default:
            guard client.authed else {
                client.send(["op": "error", "code": "auth_required", "message": "请先认证"])
                return
            }
            handleAuthed(op, object, client)
        }
    }

    private func handleHello(_ object: [String: Any], _ client: ScreenClient) {
        let version = object["v"] as? Int ?? 0
        guard version == 1 else {
            client.send(["op": "error", "code": "version", "message": "协议版本不兼容"])
            return
        }
        client.helloMid = object["mid"] as? String ?? ""
        client.helloName = object["name"] as? String ?? "手机"
        client.challenge = RelayCrypto.randomBytes(32)
        client.send([
            "op": "challenge",
            "challenge": client.challenge.base64EncodedString(),
            "mid": pairing.mid,
        ])
    }

    private func handleAuth(_ object: [String: Any], _ client: ScreenClient) {
        guard !client.helloMid.isEmpty, !client.challenge.isEmpty else {
            client.send(["op": "error", "code": "auth_required", "message": "缺少 HELLO"])
            return
        }
        guard let encoded = object["mac"] as? String,
              let mac = Data(base64Encoded: encoded),
              pairing.verify(deviceMid: client.helloMid, challenge: client.challenge, mac: mac) else {
            client.send(["op": "error", "code": "auth_failed", "message": "认证失败"])
            return
        }
        client.authed = true
        client.send(["op": "auth_ok", "session": UUID().uuidString])
        log.event("screen_auth_ok", ["mid": client.helloMid])
    }

    private func handleAuthed(_ op: String, _ object: [String: Any], _ client: ScreenClient) {
        switch op {
        case "start":
            if Permissions.screenRecording != .granted {
                Permissions.requestScreenRecordingPrompt()
                client.send([
                    "op": "error",
                    "code": "screen_permission",
                    "message": "请在 Mac 的“系统设置 › 隐私与安全性 › 屏幕录制”中允许 VoiceRelay，然后重启 App。",
                ])
                return
            }
            let width = object["width"] as? Int ?? 1280
            let height = object["height"] as? Int ?? 800
            let fps = object["fps"] as? Int ?? 30
            let follow = object["follow"] as? Bool ?? true
            let session = client.session ?? ScreenSession()
            client.session = session
            session.send = { [weak client] payload in client?.send(payload) }
            session.onActiveChange = { [weak self] active in
                self?.onActiveChange?(active)
            }
            session.prepare(width: width, height: height, fps: fps, follow: follow)
        case "answer":
            guard let sdp = object["sdp"] as? String else { return }
            client.session?.handleAnswer(sdp)
        case "ice":
            guard let candidate = object["candidate"] as? String else { return }
            let mid = object["sdpMid"] as? String
            let index = (object["sdpMLineIndex"] as? NSNumber)?.int32Value
            client.session?.handleICE(candidate: candidate, sdpMid: mid, sdpMLineIndex: index)
        case "list":
            guard let session = client.session else {
                client.send(["op": "error", "code": "not_started", "message": "请先开始屏幕会话"])
                return
            }
            Task { [weak client] in
                let windows = await session.listWindows()
                let items: [[String: Any]] = windows.map { item in
                    [
                        "id": Int(item.id),
                        "app": item.appName,
                        "title": item.title,
                        "w": Int(item.frame.width),
                        "h": Int(item.frame.height),
                        "focused": false,
                        "current": session.currentWindowID == item.id,
                    ]
                }
                client?.send(["op": "windows", "items": items])
                for item in windows.prefix(12) {
                    if let data = await ThumbnailProvider.jpeg(for: item.window) {
                        client?.send([
                            "op": "thumb",
                            "id": Int(item.id),
                            "mime": "image/jpeg",
                            "data": data.base64EncodedString(),
                        ])
                    }
                }
            }
        case "select", "switch":
            guard let session = client.session else { return }
            let windowID = (object["windowId"] as? NSNumber)?.uint32Value
            guard let windowID else {
                client.send(["op": "error", "code": "bad_window", "message": "缺少窗口 ID"])
                return
            }
            let follow = object["follow"] as? Bool ?? (op == "select")
            Task { await session.selectWindow(id: windowID, follow: follow) }
        case "follow":
            let enabled = object["enabled"] as? Bool ?? true
            client.session?.setFollow(enabled)
        case "stop":
            client.session?.stop()
            client.session = nil
        default:
            client.send(["op": "error", "code": "unknown_op", "message": "未知操作：\(op)"])
        }
    }

    private func drop(_ client: ScreenClient) {
        guard clients.removeValue(forKey: ObjectIdentifier(client)) != nil else { return }
        client.session?.stop()
        client.session = nil
        log.event("screen_client_disconnected", ["id": client.id.uuidString])
    }
}

private final class ScreenClient {
    let id = UUID()
    let connection: NWConnection
    var buffer = Data()
    var helloMid = ""
    var helloName = ""
    var challenge = Data()
    var authed = false
    var session: ScreenSession?

    init(connection: NWConnection) {
        self.connection = connection
    }

    func send(_ object: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            return
        }
        var line = data
        line.append(0x0A)
        connection.send(content: line, completion: .contentProcessed { _ in })
    }
}
