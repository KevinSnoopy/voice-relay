import Foundation
import Network
import AppKit

public struct RelaySnapshot: Equatable {
    public var connected: Bool
    public var clientName: String?
    public var level: Int
    public var backend: String
    public var model: String
    public var port: Int
    public var lastError: String?
    public var virtualDevice: String?

    public init(
        connected: Bool = false,
        clientName: String? = nil,
        level: Int = 0,
        backend: String = "A",
        model: String = "未加载",
        port: Int = 8787,
        lastError: String? = nil,
        virtualDevice: String? = nil
    ) {
        self.connected = connected
        self.clientName = clientName
        self.level = level
        self.backend = backend
        self.model = model
        self.port = port
        self.lastError = lastError
        self.virtualDevice = virtualDevice
    }
}

public struct DeliveredText {
    public static let imeUnconfirmedReason = "ime_unconfirmed"

    public var text: String
    public var ok: Bool
    public var path: String
    public var reason: String?
    public var appName: String
    public var bundleId: String
    public var totalMs: Int
    public var asrMs: Int
    public var injectMs: Int
    public var charCount: Int

    public var isConfirmedDelivery: Bool { ok && path != "ime" }

    public var statusLabel: String {
        if path == "ime" { return "已发送到输入法 · 未确认" }
        return ok ? "已上屏" : "未送达"
    }

    public var displayText: String {
        path == "ime" ? "已发送到输入法，等待上屏结果" : text
    }
}

public protocol RelayServerDelegate: AnyObject {
    func relayServer(_ server: RelayServer, didChange snapshot: RelaySnapshot)
    func relayServer(_ server: RelayServer, didDeliver result: DeliveredText)
    func relayServer(_ server: RelayServer, didFail code: Int, message: String)
    func relayServer(_ server: RelayServer, didControlFeedback result: CommandResult)
    func relayServer(_ server: RelayServer, didReceiveAudio level: Int)
}

public extension RelayServerDelegate {
    func relayServer(_ server: RelayServer, didReceiveAudio level: Int) {}
    func relayServer(_ server: RelayServer, didControlFeedback result: CommandResult) {}
}

public enum RelayServerError: Error, CustomStringConvertible {
    case invalidPort(Int)
    case listenerFailed(String)

    public var description: String {
        switch self {
        case .invalidPort(let p): return "invalid port \(p)"
        case .listenerFailed(let detail): return "listener failed: \(detail)"
        }
    }
}

public final class RelayServer {
    public weak var delegate: RelayServerDelegate?

    public private(set) var snapshot = RelaySnapshot()
    public let pairing: PairingStore
    public private(set) var lastText: String = ""

    private let settings: AppSettings
    private let asr: ASREngine
    private let log: RelayLog
    private let queue = DispatchQueue(label: "com.voicerelay.server")
    private let asrQueue = DispatchQueue(label: "com.voicerelay.asr", qos: .userInitiated)
    private let injector: TextInjector
    private let controller: AppController
    private let virtualSink = VirtualMicSink()
    private var activeBackend: String

    private var listener: NWListener?
    private var clients: [ObjectIdentifier: Client] = [:]
    private var started = false
    private var stateTimer: DispatchSourceTimer?

    public init(settings: AppSettings, asr: ASREngine, pairing: PairingStore, log: RelayLog = .shared) {
        self.settings = settings
        self.asr = asr
        self.pairing = pairing
        self.log = log
        self.controller = AppController(settings: settings)
        self.injector = TextInjector(allowPasteFallback: settings.allowPasteInjection)
        let device = VirtualMicSink.findPreferredDevice()
        self.activeBackend = (settings.backend == "B" && device == nil) ? "A" : settings.backend
        self.snapshot.backend = activeBackend
        self.snapshot.model = asr.modelLabel
        self.snapshot.port = settings.port
        self.snapshot.virtualDevice = device?.name
    }

    /// UI-driven backend switch. Returns false when B is requested without a virtual device.
    @discardableResult
    public func selectBackend(_ value: String) -> Bool {
        let normalized = value.uppercased()
        guard normalized == "A" || normalized == "B" else { return false }
        if normalized == "B" && VirtualMicSink.findPreferredDevice() == nil { return false }
        queue.async { [weak self] in
            guard let self else { return }
            for client in self.clients.values {
                client.stream?.levelTimer?.cancel()
                if client.stream?.backend == "B" { self.virtualSink.stop() }
                client.stream = nil
            }
            self.activeBackend = normalized
            self.snapshot.backend = normalized
            self.publish()
        }
        return true
    }

    public var localIPv4Address: String? { Self.localIPv4() }

    public func refreshDevices() {
        queue.async { [weak self] in
            guard let self else { return }
            self.snapshot.virtualDevice = VirtualMicSink.findPreferredDevice()?.name
            self.publish()
        }
    }

    public func start() throws {
        guard !started else { return }
        guard let port = NWEndpoint.Port(rawValue: UInt16(settings.port)) else {
            throw RelayServerError.invalidPort(settings.port)
        }
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = false

        let listener = try NWListener(using: parameters, on: port)
        listener.service = NWListener.Service(
            name: serviceName,
            type: "_voicerelay._tcp",
            txtRecord: Self.txtRecord(
                version: 1,
                mid: pairing.mid,
                port: settings.port,
                name: Host.current().localizedName ?? "Mac"
            )
        )
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.log.event("server_ready", ["port": self.settings.port])
                self.publish()
            case .failed(let error):
                self.log.event("server_failed", ["error": String(describing: error)])
                self.snapshot.lastError = String(describing: error)
                self.publish()
            case .cancelled:
                self.log.event("server_cancelled")
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        self.listener = listener
        listener.start(queue: queue)
        started = true
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            for client in self.clients.values where client.authed {
                self.sendState(to: client)
            }
        }
        timer.resume()
        stateTimer = timer
        snapshot.port = settings.port
        publish()
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stateTimer?.cancel()
            self.stateTimer = nil
            self.listener?.cancel()
            self.listener = nil
            for client in self.clients.values { client.connection.cancel() }
            self.clients.removeAll()
            self.started = false
            self.snapshot.connected = false
            self.publish()
        }
    }

    public func refreshASRState() {
        snapshot.model = asr.modelLabel
        publish()
    }

    public func pairingJSON() -> String {
        let payload: [String: Any] = [
            "v": 1,
            "ip": Self.localIPv4() ?? "127.0.0.1",
            "port": settings.port,
            "tok": pairing.code,
            "exp": Int(Date().timeIntervalSince1970) + 120,
            "mid": pairing.mid,
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Connection lifecycle

    private func accept(_ connection: NWConnection) {
        let client = Client(connection: connection)
        clients[ObjectIdentifier(client)] = client
        log.event("client_connected", ["id": client.id.uuidString])
        connection.stateUpdateHandler = { [weak self, weak client] state in
            guard let self, let client else { return }
            switch state {
            case .ready:
                self.receive(on: client)
            case .failed(let error):
                self.log.event("client_failed", ["error": String(describing: error)])
                self.drop(client)
            case .cancelled:
                self.drop(client)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receive(on client: Client) {
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self, weak client] data, _, isComplete, error in
            guard let self, let client else { return }
            if let data, !data.isEmpty {
                do {
                    let frames = try client.decoder.append(data)
                    for frame in frames { self.handle(frame, from: client) }
                } catch {
                    self.log.event("protocol_error", ["error": String(describing: error)])
                    self.sendError(client, code: ErrorCode.protocolMismatch, message: "协议错误")
                    self.close(client)
                    return
                }
            }
            if isComplete || error != nil {
                self.drop(client)
                return
            }
            self.receive(on: client)
        }
    }

    private func drop(_ client: Client) {
        guard clients.removeValue(forKey: ObjectIdentifier(client)) != nil else { return }
        client.stream?.levelTimer?.cancel()
        if client.stream?.backend == "B" { virtualSink.stop() }
        client.stream = nil
        log.event("client_disconnected", ["id": client.id.uuidString])
        let anyAuthed = clients.values.contains { $0.authed }
        if !anyAuthed {
            snapshot.connected = false
            snapshot.clientName = nil
            snapshot.level = 0
            publish()
        }
    }

    private func close(_ client: Client) {
        client.connection.cancel()
        drop(client)
    }

    // MARK: - Frame dispatch

    private func handle(_ frame: Frame, from client: Client) {
        switch frame.type {
        case .hello:
            handleHello(frame, client)
        case .auth:
            handleAuth(frame, client)
        case .streamStart:
            handleStreamStart(frame, client)
        case .audio:
            handleAudio(frame, client)
        case .streamStop:
            handleStreamStop(frame, client)
        case .command:
            handleCommand(frame, client)
        case .ping:
            send(Frame(type: .pong, payload: frame.payload), to: client)
        default:
            log.event("unexpected_frame", ["type": frame.type.rawValue])
        }
    }

    private func handleHello(_ frame: Frame, _ client: Client) {
        guard let hello = try? JSONMessage.decode(HelloMessage.self, from: frame.payload) else {
            sendError(client, code: ErrorCode.protocolMismatch, message: "无法解析 HELLO")
            close(client)
            return
        }
        guard hello.v == 1 else {
            sendError(client, code: ErrorCode.protocolMismatch, message: "协议版本不兼容")
            close(client)
            return
        }
        client.hello = hello
        client.challenge = RelayCrypto.randomBytes(32)
        let ack = HelloAckMessage(
            v: 1,
            name: Host.current().localizedName ?? "Mac",
            mid: pairing.mid,
            backend: snapshot.backend,
            perms: Permissions.summary,
            challenge: client.challenge.base64EncodedString(),
            model: asr.state == .ready ? "已加载" : "未加载"
        )
        sendJSON(ack, type: .helloAck, to: client)
        log.event("hello", ["client": hello.client, "name": hello.name])
    }

    private func handleAuth(_ frame: Frame, _ client: Client) {
        guard let hello = client.hello, !client.challenge.isEmpty else {
            sendError(client, code: ErrorCode.authFailed, message: "缺少 HELLO")
            close(client)
            return
        }
        let mac = frame.payload
        guard mac.count == 32 else {
            sendError(client, code: ErrorCode.authFailed, message: "认证失败")
            close(client)
            return
        }
        let ok = pairing.verify(deviceMid: hello.mid, challenge: client.challenge, mac: mac)
        guard ok else {
            log.event("auth_failed", ["mid": hello.mid])
            sendError(client, code: ErrorCode.authFailed, message: "配对码不正确")
            close(client)
            return
        }
        client.authed = true
        client.sessionId = UUID().uuidString
        sendJSON(AuthOKMessage(session: client.sessionId), type: .authOK, to: client)
        snapshot.connected = true
        snapshot.clientName = hello.name
        snapshot.lastError = nil
        publish()
        log.event("auth_ok", ["mid": hello.mid, "session": client.sessionId])
        sendState(to: client)
    }

    private func handleStreamStart(_ frame: Frame, _ client: Client) {
        guard client.authed else { return }
        guard let start = try? JSONMessage.decode(StreamStartMessage.self, from: frame.payload) else {
            sendError(client, code: ErrorCode.protocolMismatch, message: "STREAM_START 无效")
            return
        }
        guard start.sr == 16000, start.ch == 1, start.codec == "pcm16" || start.codec == "opus" else {
            sendError(client, code: ErrorCode.protocolMismatch, message: "仅支持 16k 单声道 pcm16/opus")
            return
        }
        var backend = activeBackend
        if backend == "B" {
            if let device = VirtualMicSink.findPreferredDevice() {
                do {
                    try virtualSink.start(device: device)
                } catch {
                    backend = "A"
                    activeBackend = "A"
                    snapshot.backend = "A"
                    sendError(client, code: ErrorCode.backendUnavailable, message: "虚拟声卡启动失败，已回落后端 A")
                    publish()
                }
            } else {
                backend = "A"
                activeBackend = "A"
                snapshot.backend = "A"
                sendError(client, code: ErrorCode.backendUnavailable, message: "虚拟声卡缺失，已回落后端 A")
                publish()
            }
        }
        let stream = StreamState(codec: start.codec, backend: backend)
        if start.codec == "opus" {
            do {
                stream.opusDecoder = try OpusStreamDecoder()
            } catch {
                sendError(client, code: ErrorCode.asrNotReady, message: "Opus 解码器不可用")
                return
            }
        }
        client.stream?.levelTimer?.cancel()
        if client.stream?.backend == "B" { virtualSink.stop() }
        client.stream = stream
        log.event("stream_start", ["codec": start.codec, "backend": backend])
        sendLevel(0, to: client)
    }

    private func handleAudio(_ frame: Frame, _ client: Client) {
        guard client.authed, let stream = client.stream else { return }
        guard frame.payload.count >= 6 else { return }
        let payload = frame.payload
        let timestamp = UInt32(payload[payload.startIndex + 2])
            | (UInt32(payload[payload.startIndex + 3]) << 8)
            | (UInt32(payload[payload.startIndex + 4]) << 16)
            | (UInt32(payload[payload.startIndex + 5]) << 24)

        if let last = stream.lastTimestamp, timestamp <= last {
            stream.replayDrops += 1
            return
        }
        stream.lastTimestamp = timestamp
        let audioData = payload.subdata(in: (payload.startIndex + 6)..<payload.endIndex)

        let samples: [Float]
        if stream.codec == "opus" {
            do {
                samples = try stream.opusDecoder!.decode(audioData)
            } catch {
                stream.decodeErrors += 1
                return
            }
        } else {
            samples = PCM16.decode(audioData)
        }
        guard !samples.isEmpty else { return }
        stream.packetCount += 1
        stream.totalSamples += samples.count
        if stream.backend == "B" {
            virtualSink.write(samples)
        } else {
            stream.samples.append(contentsOf: samples)
            if stream.totalSamples > 16000 * 65 {
                if !stream.overflowNotified {
                    stream.overflowNotified = true
                    sendError(client, code: ErrorCode.audioOverflow, message: "音频超过最长录音")
                }
                let overflow = stream.totalSamples - 16000 * 60
                if overflow > 0 { stream.samples.removeFirst(min(overflow, stream.samples.count)) }
                stream.totalSamples = stream.samples.count
            }
        }

        var level: Float = 0
        for sample in samples { level += sample * sample }
        level = sqrt(level / Float(samples.count))
        let mapped = Int(max(0, min(100, level * 320)))
        let now = Date()
        if now.timeIntervalSince(stream.lastLevelSent) >= 0.05 {
            stream.lastLevelSent = now
            sendLevel(mapped, to: client)
            if !stream.receivedAudio {
                stream.receivedAudio = true
                delegate?.relayServer(self, didReceiveAudio: mapped)
            }
            if snapshot.level != mapped {
                snapshot.level = mapped
                publish()
            }
        }
    }

    private func handleStreamStop(_ frame: Frame, _ client: Client) {
        guard client.authed, let stream = client.stream else { return }
        stream.levelTimer?.cancel()
        client.stream = nil
        let samples = stream.samples
        let stopMessage = (try? JSONMessage.decode(StreamStopMessage.self, from: frame.payload))
        let started = Date()
        log.event("stream_stop", [
            "packets": stream.packetCount,
            "audio_ms": Int(Double(samples.count) / 16000.0 * 1000),
            "expected": stopMessage?.n ?? -1,
            "backend": stream.backend,
        ])

        if stream.backend == "B" {
            virtualSink.stop()
            let total = elapsedMs(since: started)
            log.event("ime_submitted", ["total_ms": total])
            sendResult(
                client,
                text: "",
                ok: false,
                reason: DeliveredText.imeUnconfirmedReason,
                totalMs: total,
                asrMs: 0,
                injectMs: 0,
                path: "ime"
            )
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let front = self.controller.frontApp()
                self.delegate?.relayServer(self, didDeliver: DeliveredText(
                    text: "",
                    ok: false,
                    path: "ime",
                    reason: DeliveredText.imeUnconfirmedReason,
                    appName: front?.name ?? "未知",
                    bundleId: front?.bundleId ?? "",
                    totalMs: total,
                    asrMs: 0,
                    injectMs: 0,
                    charCount: 0
                ))
            }
            return
        }

        guard !samples.isEmpty else {
            sendResult(client, text: "", ok: false, reason: "empty_audio", totalMs: 0, asrMs: 0, injectMs: 0, path: nil)
            return
        }
        guard asr.state == .ready else {
            sendError(client, code: ErrorCode.asrNotReady, message: "识别引擎未就绪")
            sendResult(client, text: "", ok: false, reason: "asr_not_ready", totalMs: 0, asrMs: 0, injectMs: 0, path: nil)
            return
        }

        asrQueue.async { [weak self, weak client] in
            guard let self, let client else { return }
            do {
                let recognition = try self.asr.transcribe(samples, sampleRate: 16000)
                self.log.event("asr_done", [
                    "asr_ms": recognition.asrMs,
                    "audio_ms": Int(recognition.audioSeconds * 1000),
                    "text_len": recognition.text.count,
                ])
                self.deliver(text: recognition.text, asrMs: recognition.asrMs, started: started, client: client)
            } catch {
                self.log.event("asr_error", ["error": String(describing: error)])
                self.sendError(client, code: ErrorCode.asrNotReady, message: "识别失败")
                self.sendResult(client, text: "", ok: false, reason: "asr_failed", totalMs: 0, asrMs: 0, injectMs: 0, path: nil)
            }
        }
    }

    private func deliver(text: String, asrMs: Int, started: Date, client: Client) {
        guard !text.isEmpty else {
            sendResult(client, text: "", ok: false, reason: "empty_text", totalMs: elapsedMs(since: started), asrMs: asrMs, injectMs: 0, path: nil)
            return
        }
        DispatchQueue.main.async { [weak self, weak client] in
            guard let self, let client else { return }
            let injectStarted = Date()
            let outcome = self.injector.inject(text)
            let injectMs = self.elapsedMs(since: injectStarted)
            let front = self.controller.frontApp()
            let total = self.elapsedMs(since: started)
            if !outcome.ok {
                let code: Int
                switch outcome.reason {
                case "secure_input": code = ErrorCode.secureInput
                case "no_accessibility", "no_focus": code = ErrorCode.noFocus
                default: code = ErrorCode.unsupportedTarget
                }
                self.sendError(client, code: code, message: outcome.reason ?? "注入失败")
            }
            if outcome.ok { self.lastText = text }
            self.sendResult(
                client,
                text: text,
                ok: outcome.ok,
                reason: outcome.reason,
                totalMs: total,
                asrMs: asrMs,
                injectMs: injectMs,
                path: outcome.path.rawValue
            )
            self.log.event("inject_done", [
                "ok": outcome.ok,
                "path": outcome.path.rawValue,
                "inject_ms": injectMs,
                "total_ms": total,
                "front_app": front?.bundleId ?? "-",
                "text_len": text.count,
            ])
            let delivered = DeliveredText(
                text: text,
                ok: outcome.ok,
                path: outcome.path.rawValue,
                reason: outcome.reason,
                appName: front?.name ?? "未知",
                bundleId: front?.bundleId ?? "",
                totalMs: total,
                asrMs: asrMs,
                injectMs: injectMs,
                charCount: text.count
            )
            self.delegate?.relayServer(self, didDeliver: delivered)
        }
    }

    private func handleCommand(_ frame: Frame, _ client: Client) {
        guard client.authed else { return }
        let payload = frame.payload
        guard payload.count >= 5 else { return }
        let subRaw = payload[payload.startIndex]
        let counter = UInt32(payload[payload.startIndex + 1])
            | (UInt32(payload[payload.startIndex + 2]) << 8)
            | (UInt32(payload[payload.startIndex + 3]) << 16)
            | (UInt32(payload[payload.startIndex + 4]) << 24)
        if counter <= client.lastCommandCounter {
            log.event("command_replay_rejected", ["sub": subRaw, "counter": counter])
            return
        }
        client.lastCommandCounter = counter
        guard let subtype = CommandSubtype(rawValue: subRaw) else {
            sendAck(client, sub: subRaw, result: CommandResult(ok: false, code: "unknown"))
            return
        }
        let argsData = payload.subdata(in: (payload.startIndex + 5)..<payload.endIndex)
        let args = (try? JSONMessage.decode(CommandArgs.self, from: argsData)) ?? CommandArgs()

        let result: CommandResult
        switch subtype {
        case .switchApp:
            guard let bundleId = args.bundleId, !bundleId.isEmpty else {
                result = CommandResult(ok: false, code: "missing_bundle")
                break
            }
            result = controller.switchApp(bundleId: bundleId)
            if result.ok { sendState(to: client) }
        case .nextApp:
            result = controller.switchToAdjacentApp(backwards: false)
            if result.ok { sendState(to: client) }
        case .previousApp:
            result = controller.switchToAdjacentApp(backwards: true)
            if result.ok { sendState(to: client) }
        case .nextWindow:
            result = controller.switchToNextWindow()
            if result.ok { sendState(to: client) }
        case .activateFocus:
            result = controller.activateInputCursor()
            if result.ok { sendState(to: client) }
        case .focusNext:
            result = controller.focusNext(backwards: false)
            if result.ok { sendState(to: client) }
        case .focusPrevious:
            result = controller.focusNext(backwards: true)
            if result.ok { sendState(to: client) }
        case .returnKey:
            result = controller.pressReturn()
            if result.ok { sendState(to: client) }
        case .shiftReturn:
            result = controller.shiftReturn()
            if result.ok { sendState(to: client) }
        case .backspace:
            result = controller.backspace(count: args.count ?? 1)
        case .switchBackend:
            let requested = (args.backend ?? "A").uppercased()
            if requested != "A" && requested != "B" {
                result = CommandResult(ok: false, code: "bad_backend")
            } else if requested == "B" && VirtualMicSink.findPreferredDevice() == nil {
                result = CommandResult(ok: false, code: "backend_unavailable", detail: "未安装虚拟声卡")
            } else {
                client.stream?.levelTimer?.cancel()
                if client.stream?.backend == "B" { virtualSink.stop() }
                client.stream = nil
                activeBackend = requested
                snapshot.backend = requested
                publish()
                sendState(to: client)
                result = CommandResult(ok: true, code: "ok", detail: requested)
            }
        case .cancel:
            client.stream?.levelTimer?.cancel()
            if client.stream?.backend == "B" { virtualSink.stop() }
            client.stream = nil
            result = CommandResult(ok: true, code: "ok")
        case .copyLast:
            if lastText.isEmpty {
                result = CommandResult(ok: false, code: "no_text")
            } else {
                result = controller.copy(lastText)
            }
        case .selectAll:
            result = controller.selectAll()
        case .undo:
            result = controller.undo()
        }
        if result.ok && subtype.changesFocus {
            NotificationCenter.default.post(name: .voiceRelayFocusDidChange, object: nil)
        }
        if subtype.showsFeedback {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.relayServer(self, didControlFeedback: result)
            }
        }
        sendAck(client, sub: subRaw, result: result)
    }

    // MARK: - Sending

    private func send(_ frame: Frame, to client: Client) {
        client.connection.send(content: frame.encoded(), completion: .contentProcessed { _ in })
    }

    private func sendJSON<T: Encodable>(_ message: T, type: MessageType, to client: Client) {
        guard let data = try? JSONMessage.encode(message) else { return }
        send(Frame(type: type, payload: data), to: client)
    }

    private func sendError(_ client: Client, code: Int, message: String) {
        sendJSON(ErrorMessage(code: code, message: message), type: .error, to: client)
        delegate?.relayServer(self, didFail: code, message: message)
    }

    private func sendLevel(_ level: Int, to client: Client) {
        sendJSON(LevelMessage(level: level), type: .level, to: client)
    }

    private func sendState(to client: Client) {
        let target = controller.focusTarget()
        let state = StateMessage(
            app: target.appName,
            bundleId: target.bundleId,
            backend: snapshot.backend,
            model: asr.state == .ready ? "已加载" : "未加载",
            connected: client.authed,
            port: settings.port,
            focus: target.detail,
            editable: target.editable
        )
        sendJSON(state, type: .state, to: client)
    }

    private func sendAck(_ client: Client, sub: UInt8, result: CommandResult) {
        sendJSON(
            CommandAckMessage(sub: Int(sub), ok: result.ok, code: result.code, detail: result.detail),
            type: .commandAck,
            to: client
        )
    }

    private func sendResult(
        _ client: Client,
        text: String,
        ok: Bool,
        reason: String?,
        totalMs: Int,
        asrMs: Int,
        injectMs: Int,
        path: String?
    ) {
        let result = ResultMessage(
            ok: ok,
            text: text,
            ms: totalMs,
            len: text.count,
            reason: reason,
            path: path,
            asrMs: asrMs,
            injectMs: injectMs
        )
        sendJSON(result, type: .result, to: client)
    }

    private func publish() {
        let value = snapshot
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.relayServer(self, didChange: value)
        }
    }

    private func elapsedMs(since date: Date) -> Int {
        Int(Date().timeIntervalSince(date) * 1000)
    }

    private var serviceName: String {
        let host = Host.current().localizedName ?? "Mac"
        return "VoiceRelay-\(host)"
    }

    private static func txtRecord(version: Int, mid: String, port: Int, name: String) -> Data {
        let entries = ["v": "\(version)", "mid": mid, "port": "\(port)", "name": name]
        var data = Data()
        for (key, value) in entries.sorted(by: { $0.key < $1.key }) {
            let string = "\(key)=\(value)"
            let bytes = Array(string.utf8.prefix(255))
            data.append(UInt8(bytes.count))
            data.append(contentsOf: bytes)
        }
        return data
    }

    private static func localIPv4() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let interface = current.pointee
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name.hasPrefix("en") || name.hasPrefix("bridge") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let value = String(cString: hostname)
                        if !value.hasPrefix("127.") {
                            address = value
                            break
                        }
                    }
                }
            }
            pointer = interface.ifa_next
        }
        return address
    }
}

// MARK: - Per-client state

private final class Client {
    let id = UUID()
    let connection: NWConnection
    var decoder = FrameDecoder()
    var hello: HelloMessage?
    var challenge = Data()
    var authed = false
    var sessionId = ""
    var stream: StreamState?
    var lastCommandCounter: UInt32 = 0

    init(connection: NWConnection) {
        self.connection = connection
    }
}

private final class StreamState {
    let codec: String
    let backend: String
    var samples: [Float] = []
    var totalSamples = 0
    var packetCount = 0
    var lastTimestamp: UInt32?
    var replayDrops = 0
    var decodeErrors = 0
    var opusDecoder: OpusStreamDecoder?
    var lastLevelSent = Date.distantPast
    var overflowNotified = false
    var levelTimer: DispatchSourceTimer?
    var receivedAudio = false

    init(codec: String, backend: String = "A") {
        self.codec = codec
        self.backend = backend
    }
}

public struct CommandArgs: Codable {
    public var bundleId: String?
    public var count: Int?
    public var backend: String?

    public init(bundleId: String? = nil, count: Int? = nil, backend: String? = nil) {
        self.bundleId = bundleId
        self.count = count
        self.backend = backend
    }
}
