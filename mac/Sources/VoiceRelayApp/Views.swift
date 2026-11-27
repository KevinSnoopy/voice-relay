import SwiftUI
import AppKit
import VoiceRelayCore

private let accent = Color(red: 0.04, green: 0.42, blue: 1.0)

struct PopoverView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var showQR = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if state.permissions["accessibility"] != .granted {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("需要辅助功能权限才能直接写入光标")
                    Spacer()
                    Button("去授权") { state.requestAccessibility() }
                        .buttonStyle(.link)
                }
                .font(.system(size: 10))
                .foregroundStyle(Color.orange)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(Color.orange.opacity(0.08))
            }
            levelArea
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 320, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showQR) {
            PairingSheet().environmentObject(state)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Button {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("设置")
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var levelArea: some View {
        HStack(alignment: .center, spacing: 10) {
            LevelBars(level: state.snapshot.level, active: state.snapshot.connected)
                .frame(width: 210, height: 44)
            Spacer()
            if state.snapshot.connected {
                Text(state.snapshot.level > 0 ? "收音中" : "待命")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
    }

    @ViewBuilder
    private var content: some View {
        if state.snapshot.connected {
            VStack(alignment: .leading, spacing: 0) {
                Text("最近上屏")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                if state.recent.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 22))
                            .foregroundStyle(.tertiary)
                        Text("还没有上过屏")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(state.recent.enumerated()), id: \.offset) { _, item in
                                Button {
                                    state.copy(item.text)
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.displayText)
                                                .font(.system(size: 12))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            Text("\(item.appName) · \(item.totalMs) ms · \(item.statusLabel)")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: item.path == "ime" ? "arrow.up.circle.fill" : (item.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"))
                                            .foregroundStyle(item.path == "ime" ? accent : (item.ok ? Color.green : Color.orange))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: 10) {
                Text("等待手机连接")
                    .font(.system(size: 13, weight: .medium))
                Text(state.pairingCode)
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
                Text("在手机上输入这 6 位配对码")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button("显示二维码") { showQR = true }
                    Button("重新生成") { state.rotatePairingCode() }
                }
                .padding(.top, 2)
                if let error = state.lastError {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(state.snapshot.connected ? "手机 已连接" : "手机 未连接")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(state.snapshot.backend == "B" ? "B · 输入法" : "A · 本地")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
            HStack {
                Button("设置…") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("退出") { state.quit() }
            }
            .buttonStyle(.link)
            .padding(.horizontal, 16)
            .frame(height: 38)
        }
    }

    private var statusText: String {
        if state.modelLoading { return "模型加载中" }
        if state.snapshot.connected { return "已连接 · \(state.snapshot.clientName ?? "")" }
        if let error = state.lastError { return error }
        return "未连接"
    }

    private var statusColor: Color {
        if state.modelLoading { return .orange }
        return state.snapshot.connected ? .green : .secondary
    }
}

struct LevelBars: View {
    let level: Int
    let active: Bool

    var body: some View {
        GeometryReader { geometry in
            let widths: [CGFloat] = [0.10, 0.17, 0.24, 0.17, 0.10]
            HStack(alignment: .center, spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    let factor = widths[index] + CGFloat(level) / 100.0 * (1 - widths[index])
                    Capsule()
                        .fill(active ? accent.opacity(0.75) : Color.secondary.opacity(0.18))
                        .frame(height: max(2, geometry.size.height * factor))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.12), value: level)
        }
    }
}

struct PairingSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Text("扫码配对")
                .font(.system(size: 15, weight: .semibold))
            if let image = state.qrImage() {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 230, height: 230)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 230, height: 230)
                    .overlay(Text("二维码不可用").foregroundStyle(.secondary))
            }
            Text("\(state.pairingHost):\(state.settings.port)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Text(state.pairingCode)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                Button("复制配对码") { state.copy(state.pairingCode) }
            }
            Text("二维码 120 秒内有效，已建立的连接不受影响。")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Button("关闭") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 320)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            GeneralSettingsView().tabItem { Label("通用", systemImage: "gearshape") }
            ConnectionSettingsView().tabItem { Label("连接", systemImage: "wifi") }
            VoiceSettingsView().tabItem { Label("语音", systemImage: "waveform") }
            KeysSettingsView().tabItem { Label("按键", systemImage: "keyboard") }
            PermissionsSettingsView().tabItem { Label("权限", systemImage: "lock.shield") }
            AboutView().tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 720, height: 520)
        .padding(.top, 4)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section {
                Toggle("开机自启", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
                Toggle("显示悬浮电平窗", isOn: binding(\.showOverlay))
                Toggle("启动时显示配对码", isOn: binding(\.showPairingOnLaunch))
            }
            Section {
                Picker("语言", selection: .constant("zh")) {
                    Text("中文").tag("zh")
                }
                Picker("最近文本条数", selection: binding(\.recentTextLimit)) {
                    Text("1").tag(1)
                    Text("3").tag(3)
                    Text("5").tag(5)
                }
            }
            Section {
                Button("重新走一遍设置向导") {
                    state.showOnboarding()
                }
                Text("这些设置随账号保存在本机，不上传。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { state.settings[keyPath: keyPath] },
            set: { state.settings[keyPath: keyPath] = $0; state.saveSettings() }
        )
    }
}

struct ConnectionSettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var showQR = false

    var body: some View {
        Form {
            Section("当前设备") {
                HStack {
                    Text(state.snapshot.connected ? (state.snapshot.clientName ?? "手机") : "没有设备连接")
                    Spacer()
                    Text(state.snapshot.connected ? "已连接" : "未连接")
                        .foregroundStyle(state.snapshot.connected ? .green : .secondary)
                }
            }
            Section("本机") {
                LabeledContent("监听地址", value: "0.0.0.0:\(state.settings.port)")
                LabeledContent("配对码", value: state.pairingCode)
                LabeledContent("虚拟声卡", value: state.snapshot.virtualDevice ?? "未检测到")
                HStack {
                    Button("显示二维码") { showQR = true }
                    Button("重新生成配对码") { state.rotatePairingCode() }
                    Spacer()
                    Text("新配对码用于新设备；已配对设备仍有效")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            if !state.server.pairing.pairedDeviceIDs.isEmpty {
                Section("已配对设备") {
                    ForEach(state.server.pairing.pairedDeviceIDs, id: \.self) { mid in
                        HStack {
                            Image(systemName: "iphone")
                            Text(String(mid.prefix(10)))
                                .font(.system(size: 12, design: .monospaced))
                            Spacer()
                            Text("长期密钥")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Button("吊销") { state.revokeDevice(mid) }
                        }
                    }
                    Text("吊销后该设备需要重新输入配对码。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Section("备用通道") {
                Toggle("启用蓝牙备用通道", isOn: Binding(
                    get: { state.settings.bleEnabled },
                    set: { state.setBLE($0) }
                ))
                LabeledContent("蓝牙状态", value: state.bleStatus)
                HStack {
                    Button("重新检测虚拟声卡") { state.server.refreshDevices() }
                    Spacer()
                    Text(state.snapshot.virtualDevice == nil ? "后端 B 需要虚拟声卡" : "已检测到虚拟声卡，使用时仍需启动验证")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Text("BLE 走 GATT 通知，首次开启会请求蓝牙权限；连接后复用同一套认证与协议。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showQR) { PairingSheet().environmentObject(state) }
    }
}

struct VoiceSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section("后端") {
                Picker("识别后端", selection: Binding(
                    get: { state.snapshot.backend },
                    set: { state.setBackend($0) }
                )) {
                    Text("A · 本地识别").tag("A")
                    Text(state.snapshot.virtualDevice == nil ? "B · 输入法（未安装虚拟声卡）" : "B · 输入法（\(state.snapshot.virtualDevice ?? "")）").tag("B")
                }
                .pickerStyle(.radioGroup)
                Text("B 后端把音频写到虚拟声卡，由输入法自己识别并上屏；切换时会结束当前收音会话。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Section("模型") {
                LabeledContent("模型", value: "SenseVoice Small（int8）· 约 230 MB")
                LabeledContent("状态", value: state.modelInstallMessage ?? state.snapshot.model)
                if state.modelInstalling {
                    if let progress = state.modelInstallProgress {
                        ProgressView(value: progress)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                    Text("首次使用需要下载约 155 MB，下载完成后会自动加载。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else if state.modelLoading {
                    ProgressView().controlSize(.small)
                } else {
                    if state.snapshot.model == "未加载" {
                        Button("下载语音模型（约 155 MB）") { state.installModel() }
                    }
                    Button("重新加载模型") { state.loadModel() }
                }
                Text("模型来自 sherpa-onnx 官方 Release，解压到 ~/Library/Application Support/VoiceRelay/models/")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Section("录音") {
                Slider(value: Binding(
                    get: { Double(state.settings.sensitivity) },
                    set: { state.settings.sensitivity = Int($0); state.saveSettings() }
                ), in: 0...100) {
                    Text("灵敏度 \(state.settings.sensitivity)")
                }
                Stepper("松手延迟 \(state.settings.releaseDelayMs) ms", value: binding(\.releaseDelayMs), in: 0...500, step: 20)
                Stepper("最长录音 \(state.settings.maxRecordSeconds) 秒", value: binding(\.maxRecordSeconds), in: 10...120, step: 10)
                Toggle("数字与金额规范化（ITN）", isOn: binding(\.useITN))
                Toggle("兼容模式：允许自动粘贴", isOn: binding(\.allowPasteInjection))
                Text("默认关闭。关闭时只走 AX/Unicode 直接写入；失败会在手机上提示，不自动占用剪贴板。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Picker("语言", selection: binding(\.asrLanguage)) {
                    Text("中文").tag("zh")
                    Text("自动（中英混说）").tag("auto")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { state.settings[keyPath: keyPath] },
            set: { state.settings[keyPath: keyPath] = $0; state.saveSettings() }
        )
    }
}

struct KeysSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section("输入框") {
                Toggle("焦点切换失败时发送 Tab", isOn: Binding(
                    get: { state.settings.focusTabFallback },
                    set: { state.settings.focusTabFallback = $0; state.saveSettings() }
                ))
            }
            Section("回车") {
                Toggle("识别完成后自动回车", isOn: Binding(
                    get: { state.settings.echoReturn },
                    set: { state.settings.echoReturn = $0; state.saveSettings() }
                ))
            }
        }
        .formStyle(.grouped)
    }
}

struct PermissionsSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("权限")
                    .font(.system(size: 15, weight: .semibold))
                Text("授权后如果仍不生效，点下面的「重新检测」。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("当前运行：\(Bundle.main.bundlePath)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if state.runningFromBuildDirectory {
                    Text("正在运行 build 副本。请改用 /Applications/VoiceRelay.app，否则辅助功能授权会对不上。")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }

                PermissionCard(
                    title: "辅助功能",
                    summary: "把文字写进其他 App 的输入框",
                    why: "VoiceRelay 需要把识别出的文字直接写进你正在用的 App。授权后就相当于你允许它代替你敲键盘。",
                    status: state.permissions["accessibility"] ?? .unknown,
                    action: { Permissions.openSettings("accessibility") },
                    extra: { Permissions.requestAccessibilityPrompt() }
                )
                PermissionCard(
                    title: "屏幕录制",
                    summary: "让手机看到 Mac 上的窗口",
                    why: "屏幕共享需要读取窗口画面。画面只在局域网内通过 WebRTC 加密传输，停止共享后立即释放；不会写入磁盘。",
                    status: state.permissions["screen_recording"] ?? .unknown,
                    action: { Permissions.openSettings("screen_recording") },
                    extra: { Permissions.requestScreenRecordingPrompt() }
                )
                PermissionCard(
                    title: "输入监控",
                    summary: "为后续输入法语音键预留，当前版本不需要",
                    why: "当前后端 B 只写虚拟声卡，不会模拟输入法语音键，因此无需授权。",
                    status: state.permissions["input_monitoring"] ?? .unknown,
                    isRelevant: false,
                    action: { Permissions.openSettings("input_monitoring") },
                    extra: nil
                )
                PermissionCard(
                    title: "蓝牙",
                    summary: "网络不通时用蓝牙传输语音",
                    why: "公司网络或访客 Wi-Fi 常常禁止设备互访，这时可切换到蓝牙备用通道。",
                    status: state.permissions["bluetooth"] ?? .unknown,
                    isRelevant: state.settings.bleEnabled,
                    action: { Permissions.openSettings("bluetooth") },
                    extra: nil
                )

                HStack {
                    Button("重新检测") { state.refreshPermissions() }
                    Spacer()
                    Text("状态每 2 秒自动刷新")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }
}

struct PermissionCard: View {
    let title: String
    let summary: String
    let why: String
    let status: Permissions.Status
    var isRelevant: Bool = true
    let action: () -> Void
    let extra: (() -> Void)?

    var body: some View {
        let attention = status != .granted && isRelevant
        let label = !isRelevant && status != .granted ? "当前不需要" : statusText
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: status == .granted ? "checkmark.circle.fill" : (isRelevant ? "exclamationmark.triangle.fill" : "minus.circle"))
                    .foregroundStyle(status == .granted ? Color.green : (isRelevant ? Color.orange : Color.secondary))
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(status == .granted ? Color.green : (isRelevant ? Color.orange : Color.secondary))
            }
            Text(summary)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack {
                Button("打开系统设置", action: action)
                if let extra, status != .granted { Button("请求授权", action: extra) }
                Spacer()
            }
            DisclosureGroup("为什么需要这个权限？") {
                Text(why)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .font(.system(size: 11))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(attention ? Color.orange.opacity(0.07) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(attention ? Color.orange.opacity(0.35) : Color.secondary.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var statusText: String {
        switch status {
        case .granted: return "已授权"
        case .denied: return "未授权"
        case .unknown: return "待确认"
        }
    }
}

struct AboutView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(accent)
                VStack(alignment: .leading) {
                    Text("VoiceRelay").font(.system(size: 16, weight: .semibold))
                    Text("1.0.0 (1) · 自用版").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Divider()
            LabeledContent("日志目录", value: "~/Library/Logs/VoiceRelay")
            Button("打开日志文件夹") {
                NSWorkspace.shared.open(RelayLog.shared.directoryURL)
            }
            Button("复制诊断信息") {
                let text = """
                VoiceRelay 1.0.0
                port=\(state.settings.port)
                connected=\(self.state.snapshot.connected)
                model=\(self.state.snapshot.model)
                accessibility=\(self.state.permissions["accessibility"]?.rawValue ?? "-")
                inputMonitoring=\(self.state.permissions["input_monitoring"]?.rawValue ?? "-")
                bluetooth=\(self.state.permissions["bluetooth"]?.rawValue ?? "-")
                """
                state.copy(text)
            }
            Text("完全自用，不做公证、不上架。文档是工程准绳。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    var onClose: (() -> Void)? = nil
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("设置 VoiceRelay").font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("第 \(step + 1) 步 / 共 3 步").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Divider()
            Group {
                switch step {
                case 0:
                    VStack(spacing: 12) {
                        Text("在手机装好 App，扫这个码")
                        if let image = state.qrImage(scale: 6) {
                            Image(nsImage: image).interpolation(.none).frame(width: 200, height: 200)
                        }
                        Text("\(state.pairingHost):\(state.settings.port)")
                            .font(.system(size: 12, design: .monospaced))
                        Text("配对码 \(state.pairingCode)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                        modelRow
                    }
                case 1:
                    VStack(alignment: .leading, spacing: 10) {
                        Text("检查权限")
                        PermissionSummaryRow(name: "辅助功能", granted: state.permissions["accessibility"] == .granted)
                        PermissionSummaryRow(name: "输入监控", granted: state.permissions["input_monitoring"] == .granted, relevant: false)
                        PermissionSummaryRow(name: "蓝牙", granted: state.permissions["bluetooth"] == .granted, relevant: state.settings.bleEnabled)
                        Text("辅助功能没授权时不能继续。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                default:
                    VStack(spacing: 10) {
                        Text("试一句：按住手机上的按钮说句话")
                        Text("松手后，文字会出现在 Mac 当前光标处。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        if state.onboardingDeliveryOK {
                            Text("已确认文字上屏，可以完成")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.green)
                        } else if state.hasReceivedAudio {
                            Text("已收到音频，但还没有确认文字上屏")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.orange)
                        } else {
                            Text("还没有收到音频")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Button("稍后再说") { close() }
                Spacer()
                if step > 0 { Button("上一步") { step -= 1 } }
                if step < 2 {
                    Button("下一步") { step += 1 }
                        .keyboardShortcut(.defaultAction)
                        .disabled(step == 1 && state.permissions["accessibility"] != .granted)
                } else {
                    Button("完成") { close() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!state.onboardingDeliveryOK)
                }
            }
        }
        .padding(24)
        .frame(width: 560, height: 400)
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private var modelRow: some View {
        if state.modelInstalling {
            VStack(spacing: 4) {
                ProgressView(value: state.modelInstallProgress ?? 0)
                    .frame(width: 260)
                Text(state.modelInstallMessage ?? "下载中…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        } else if state.snapshot.model == "未加载" {
            HStack(spacing: 8) {
                Text("语音模型未安装")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                Button("下载（约 155 MB）") { state.installModel() }
                    .controlSize(.small)
            }
        }
    }
}

struct PermissionSummaryRow: View {
    let name: String
    let granted: Bool
    var relevant: Bool = true

    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : (relevant ? "circle" : "minus.circle"))
                .foregroundStyle(granted ? Color.green : Color.secondary)
            Text(name)
            Spacer()
            Text(granted ? "已授权" : (relevant ? "未授权" : "当前不需要"))
                .font(.system(size: 11))
                .foregroundStyle(granted ? Color.green : (relevant ? Color.orange : Color.secondary))
        }
    }
}
