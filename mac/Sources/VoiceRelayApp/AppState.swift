import Foundation
import AppKit
import Combine
import CoreImage
import SwiftUI
import UserNotifications
import VoiceRelayCore

/// Thread-safe holder so the model can load after the menu bar appears.
final class ModelHolder: ASREngine {
    private let lock = NSLock()
    private var engine: ASREngine?
    private var currentState: ASRState = .loading
    private var label = "未加载"
    private var failure: String?

    var state: ASRState {
        lock.lock(); defer { lock.unlock() }
        return currentState
    }

    var modelLabel: String {
        lock.lock(); defer { lock.unlock() }
        return label
    }

    func install(_ engine: ASREngine) {
        lock.lock()
        self.engine = engine
        self.currentState = engine.state
        self.label = engine.modelLabel
        self.failure = nil
        lock.unlock()
    }

    func fail(_ reason: String) {
        lock.lock()
        self.engine = nil
        self.currentState = .unavailable(reason)
        self.failure = reason
        lock.unlock()
    }

    func transcribe(_ samples: [Float], sampleRate: Int) throws -> ASRResult {
        lock.lock()
        let engine = self.engine
        lock.unlock()
        guard let engine else { throw ASRError.modelMissing(failure ?? "模型未加载") }
        return try engine.transcribe(samples, sampleRate: sampleRate)
    }
}

final class AppState: ObservableObject, RelayServerDelegate {
    static let shared = AppState()

    @Published var snapshot = RelaySnapshot()
    @Published var recent: [DeliveredText] = []
    @Published var settings: AppSettings
    @Published var permissions: [String: Permissions.Status] = [:]
    @Published var pairingCode: String = "------"
    @Published var lastError: String?
    @Published var showOnboardingOnLaunch = false
    @Published var modelLoading = true
    @Published var modelInstalling = false
    @Published var modelInstallProgress: Double?
    @Published var modelInstallMessage: String?
    @Published var bleStatus = "未开启"
    @Published var hasReceivedAudio = false
    @Published var onboardingDeliveryOK = false
    @Published var launchAtLogin = false
    @Published var pairingRevision = 0
    @Published var screenSharing = false
    @Published var screenWindowTitle = ""

    private(set) var server: RelayServer!
    private(set) var screenServer: ScreenShareServer?
    private let holder = ModelHolder()
    private let pairing: PairingStore
    private let ble: BLEBridge
    private let overlay = LevelOverlayController()
    private let switchHUD = SwitchHudController()
    var onboardingWindow: OnboardingWindowController?
    private var permissionTimer: Timer?
    private var started = false
    private var installer: ModelInstaller?

    var pairingHost: String { server.localIPv4Address ?? "127.0.0.1" }
    var runningFromBuildDirectory: Bool { Bundle.main.bundlePath.contains("/build/") }

    private init() {
        var loaded = AppSettings.load()
        if let port = UserDefaults.standard.object(forKey: "VoiceRelayPort") as? Int { loaded.port = port }
        self.settings = loaded
        self.pairing = PairingStore()
        self.ble = BLEBridge(port: loaded.port)
        self.launchAtLogin = LaunchAtLogin.isEnabled
        let log = RelayLog.shared
        self.server = RelayServer(settings: loaded, asr: holder, pairing: pairing, log: log)
        server.delegate = self
        let screenPort = UInt16(min(65535, max(1024, loaded.port + 1)))
        self.screenServer = ScreenShareServer(port: screenPort, pairing: pairing, log: log)
        screenServer?.onActiveChange = { [weak self] active in
            DispatchQueue.main.async {
                self?.screenSharing = active
            }
        }
        pairingCode = pairing.code
        ble.onStatus = { [weak self] status in
            DispatchQueue.main.async { self?.bleStatus = status.label }
        }
        ble.onLog = { message in
            RelayLog.shared.event("ble", ["message": message])
        }
        refreshPermissions()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshPermissionState()
        }
        requestNotificationPermission()
        start()
        loadModel()
        if !UserDefaults.standard.bool(forKey: "VoiceRelayOnboarded") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.showOnboarding()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPermissions()
        }
    }

    func start() {
        guard !started else { return }
        do {
            try server.start()
            try screenServer?.start()
            started = true
            if settings.bleEnabled { ble.start() }
        } catch {
            lastError = "启动失败：\(error)"
        }
        if Permissions.accessibility != .granted,
           !UserDefaults.standard.bool(forKey: "VoiceRelayAXPrompted") {
            UserDefaults.standard.set(true, forKey: "VoiceRelayAXPrompted")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Permissions.requestAccessibilityPrompt()
            }
        }
    }

    func requestAccessibility() {
        Permissions.requestAccessibilityPrompt()
    }

    func setBLE(_ enabled: Bool) {
        settings.bleEnabled = enabled
        saveSettings()
        if enabled {
            ble.start()
        } else {
            ble.stop()
            bleStatus = "未开启"
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if let error = LaunchAtLogin.set(enabled) {
            lastError = "开机自启设置失败：\(error)"
            return
        }
        launchAtLogin = enabled
        settings.launchAtLogin = enabled
        saveSettings()
    }

    func setBackend(_ value: String) {
        guard server.selectBackend(value) else {
            lastError = "未安装虚拟声卡，后端 B 不可用"
            return
        }
        settings.backend = value
        saveSettings()
    }

    func revokeDevice(_ mid: String) {
        server.pairing.revoke(deviceMid: mid)
        pairingRevision += 1
    }

    func showOnboarding() {
        hasReceivedAudio = false
        onboardingDeliveryOK = false
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindowController(state: self)
        }
        onboardingWindow?.showWindow(nil)
        onboardingWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func installModel() {
        guard !modelInstalling else { return }
        let installer = ModelInstaller()
        self.installer = installer
        modelInstalling = true
        modelInstallProgress = 0
        modelInstallMessage = "准备下载…"
        Task {
            do {
                _ = try await installer.install { fraction, message in
                    DispatchQueue.main.async {
                        self.modelInstallProgress = fraction
                        self.modelInstallMessage = message
                    }
                }
                await MainActor.run {
                    self.modelInstalling = false
                    self.modelInstallProgress = nil
                    self.modelInstallMessage = "模型已安装"
                    self.installer = nil
                    self.loadModel()
                }
            } catch {
                await MainActor.run {
                    self.modelInstalling = false
                    self.modelInstallProgress = nil
                    self.modelInstallMessage = nil
                    self.installer = nil
                    self.lastError = "模型下载失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func loadModel() {
        modelLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let engine = try SherpaSenseVoiceEngine(language: self.settings.asrLanguage, useITN: self.settings.useITN)
                self.holder.install(engine)
                DispatchQueue.main.async {
                    self.modelLoading = false
                    self.snapshot.model = engine.modelLabel
                    self.server.refreshASRState()
                }
            } catch {
                self.holder.fail(String(describing: error))
                DispatchQueue.main.async {
                    self.modelLoading = false
                    self.snapshot.model = "未加载"
                    self.lastError = "模型加载失败：\(error)"
                }
            }
        }
    }

    func refreshPermissions() {
        refreshPermissionState()
        if settings.bleEnabled { server.refreshDevices() }
    }

    private func refreshPermissionState() {
        permissions = [
            "accessibility": Permissions.accessibility,
            "input_monitoring": Permissions.inputMonitoring,
            "bluetooth": Permissions.bluetooth,
            "screen_recording": Permissions.screenRecording,
        ]
    }

    func rotatePairingCode() {
        pairing.rotateCode()
        pairingCode = pairing.code
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func saveSettings() {
        settings.save()
        UserDefaults.standard.set(settings.port, forKey: "VoiceRelayPort")
        if !settings.showOverlay { overlay.update(level: 0, visible: false) }
    }

    func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "VoiceRelay 设置" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    func quit() {
        ble.stop()
        overlay.close()
        switchHUD.close()
        screenServer?.stop()
        server.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { NSApp.terminate(nil) }
    }

    func qrImage(scale: CGFloat = 7) -> NSImage? {
        let payload = server.pairingJSON()
        guard let data = payload.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: transformed)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyFailure(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "VoiceRelay"
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - RelayServerDelegate

    func relayServer(_ server: RelayServer, didChange snapshot: RelaySnapshot) {
        DispatchQueue.main.async {
            self.snapshot = snapshot
            self.modelLoading = snapshot.model == "未加载" && self.lastError == nil
            self.overlay.update(
                level: snapshot.level,
                visible: self.settings.showOverlay && snapshot.connected && snapshot.level > 0
            )
        }
    }

    func relayServer(_ server: RelayServer, didReceiveAudio level: Int) {
        DispatchQueue.main.async {
            self.hasReceivedAudio = true
            self.overlay.update(level: level, visible: self.settings.showOverlay)
        }
    }

    func relayServer(_ server: RelayServer, didDeliver result: DeliveredText) {
        DispatchQueue.main.async {
            self.recent.insert(result, at: 0)
            if self.recent.count > max(1, self.settings.recentTextLimit) { self.recent.removeLast() }
            if result.isConfirmedDelivery {
                self.lastError = nil
                self.onboardingDeliveryOK = true
            }
            self.hasReceivedAudio = true
            self.overlay.update(level: 0, visible: false)
            if !result.ok && result.path != "ime", let reason = result.reason {
                self.notifyFailure(Self.humanReason(reason))
            }
        }
    }

    func relayServer(_ server: RelayServer, didFail code: Int, message: String) {
        DispatchQueue.main.async {
            self.lastError = message
            if code == ErrorCode.noFocus || code == ErrorCode.secureInput || code == ErrorCode.unsupportedTarget {
                self.notifyFailure(Self.humanReason(message))
            }
        }
    }

    func relayServer(_ server: RelayServer, didControlFeedback result: CommandResult) {
        let message = result.ok ? (result.detail ?? "操作完成") : "操作失败：\(result.detail ?? result.code)"
        DispatchQueue.main.async {
            self.switchHUD.show(message)
        }
    }

    static func humanReason(_ raw: String) -> String {
        switch raw {
        case "no_accessibility": return "Mac 没拿到辅助功能权限；请在系统设置里授权后重试"
        case "no_focus": return "当前没有可输入的位置"
        case "secure_input": return "密码框不支持语音输入"
        case "direct_injection_failed": return "这个输入框不支持直接写入"
        case "asr_not_ready": return "识别引擎还没准备好"
        case "empty_text", "empty_audio": return "没有识别到文字"
        case DeliveredText.imeUnconfirmedReason: return "已发送到输入法，上屏结果未确认"
        default: return raw
        }
    }
}
