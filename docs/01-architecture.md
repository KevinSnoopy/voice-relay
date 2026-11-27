# 01 · 总体架构

## 1. 设计目标

| 目标 | 衡量方式 |
|---|---|
| 说完 1 秒内出字 | 松手到文字出现在输入框的 P95 < 1000 ms |
| 不打断用户手头的事 | 不抢焦点、不改系统默认输入/输出设备 |
| 在公司网络也能用 | 至少一条通道在客户端隔离下可用 |
| 不依赖第三方输入法 | 默认后端自给自足 |
| 单机可维护 | 只有一份代码，一个人能改 |

## 2. 为什么识别放在 Mac

| 方案 | 中文准确率 | Android 无 GMS | Intel Mac 可行性 | 结论 |
|---|---|---|---|---|
| 手机本地识别 | 系统级中文识别受厂商与 GMS 影响大 | ❌ 不可用 | — | 否 |
| 手机调云端 | 高 | ✅ | — | 需要网络与费用 |
| **Mac 本地 sherpa-onnx** | 好（SenseVoice / Paraformer） | ✅ 与手机无关 | ✅ 官方有 osx-x64 预编译库 | **默认** |
| 第三方输入法识别 | 最好 | ✅ | ✅ | 第二后端 |

选择 Mac 端识别的连带好处：手机退化成"麦克风 + 遥控器"，不必处理中文注入、不必处理 GMS、不必处理各厂商语音服务差异。

## 3. 组件图

```
┌──────────── 手机「语音遥控」（Flutter）────────────┐
│ 语音页  │ 控制面板 │ 设置 │ 连接管理                │
│ 录音 16k ─ Opus 编码 ─ 发送队列（背压、丢旧帧）      │
│ 按键事件 ─ 立即发送（高优先级，独立于音频通道）      │
└───────────────┬────────────────────────────────────┘
                │ ① Wi-Fi：Bonjour 发现 / 二维码直连，TCP
                │ ② BLE：GATT notify（网络不可用时）
┌───────────────┴────────────────────────────────────┐
│              Mac VoiceRelay.app（菜单栏常驻）        │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│ │Transport │→│  ASR     │→│ Injector │ │Control  │ │
│ │WiFi/BLE  │ │sherpa-onnx│ │AX/Uni/Paste│ │App/焦点 │ │
│ └──────────┘ └────┬─────┘ └──────────┘ └─────────┘ │
│                   └→ VirtualMic 后端（写虚拟声卡）   │
│  Permissions · SecureInput · 日志 · 设置             │
└─────────────────────────────────────────────────────┘
```

## 4. 双后端与互斥规则

| 后端 | 音频去向 | 谁识别 | 上屏方式 | 额外权限 |
|---|---|---|---|---|
| **A · 本地识别**（默认） | sherpa-onnx | Mac App | AX / Unicode / 粘贴 | 辅助功能 |
| **B · 虚拟声卡** | BlackHole 派生设备 | 第三方输入法 | 输入法自己上屏 | 辅助功能 + 输入监控 |

互斥规则（必须硬编码保证）：

1. 同一时刻只允许一个后端持有"收音会话"。
2. 切换后端时必须先结束当前会话，并等待至少 300 ms 再启动新会话。
3. B 后端启动前必须检查：虚拟设备存在、目标输入法正在运行、输入法语音键配置已知。
4. 任一后端连续失败 2 次，自动回落到 A，并在 UI 上说明原因。

## 5. 模块职责

### Mac 端

| 模块 | 职责 | 关键 API |
|---|---|---|
| `Transport/WiFi` | TCP 监听、Bonjour 广播、二维码邀请 | `NWListener`、`NWBrowser`、`NetService` |
| `Transport/BLE` | 外设广播、notify 推流、背压 | `CBPeripheralManager` |
| `AudioPipeline` | Opus 解码、48k→16k 重采样、分帧 | `AVAudioConverter`、`libopus` |
| `ASREngine` | 流式/整段识别，输出 partial 与 final | sherpa-onnx C API |
| `Injector` | 三级文本注入 | `AXUIElement`、`CGEvent`、`NSPasteboard` |
| `Controller` | 切 App、切输入框、Secure Input 判定 | `NSWorkspace`、AX |
| `VirtualMicSink` | 写音频到虚拟声卡 | CoreAudio HAL 输出 |
| `PermissionCenter` | 权限状态与引导 | `AXIsProcessTrusted`、`CBManager.authorization`、`IOHIDCheckAccess` |
| `SessionStore` | 长期密钥、最近文本、设置 | Keychain / UserDefaults |

### 手机端（Flutter）

| 模块 | 职责 |
|---|---|
| `connection` | 发现、配对、重连、连接状态机 |
| `transport` | TCP 客户端 / BLE central，统一 `Channel` 抽象 |
| `audio` | 录音（16 kHz 单声道）、Opus 编码、发送队列 |
| `commands` | 按键指令（切 App、焦点、回车、删除） |
| `ui` | 语音页、控制面板、设置、引导 |

## 6. 关键数据流

**语音（默认后端）**

```
按住 → 手机开始 16k 采集 → 20 ms 一帧进编码器 → 40 ms 一个 Opus 包
     → 发送队列（上限 8 包，满了丢最旧）→ Wi-Fi → Mac 解码
     → 16k PCM 环形缓冲 → sherpa-onnx 流式/整段
松手 → 发送 STREAM_STOP → Mac 收尾识别 → final 文本 → Injector → 回传 RESULT
```

**控制**

```
点按 App 图标 → CMD_SWITCH_APP(bundleId) → Mac NSWorkspace.activate
点按"下一个输入框" → CMD_FOCUS_NEXT → AX 遍历 → 成功/失败回传
```

**状态回传**（Mac → 手机，低频）

```
电平（50 ms 一次，收音中）、当前前台 App、最终文本、错误码、后端状态
```

## 7. 运行环境基线

| 项 | 值 | 备注 |
|---|---|---|
| Mac | Intel x86_64，macOS 13.7.8 | 已验证环境 |
| Xcode | 15.2（iOS SDK 17.2） | iOS 18+ 真机需要升级，见 Q-03 |
| sherpa-onnx | v2.0.3，`osx-x64` 静态库 | 官方预编译，无需自行编译 |
| 手机 | iOS 15+ / Android（无 GMS） | Flutter 最低版本按 iOS 15 设 |
| 网络 | 家庭 Wi-Fi / 公司 Wi-Fi | 公司需 BLE 兜底 |

## 8. 命名与部署

| 端 | 名称 | 备注 |
|---|---|---|
| 手机 | 语音遥控 | 原型 v1.0 |
| Mac | VoiceRelay | 菜单栏 App，端口 8787 |
| 虚拟声卡 | SayAll 风格设备（自建） | 仅 B 后端 |


| 端 | 方式 |
|---|---|
| Mac | 一个 `.app`，放到 `/Applications`，自签名；虚拟声卡单独 `.pkg`（可选安装） |
| iOS | Xcode 直装真机，个人开发者证书 |
| Android | `flutter build apk`，直接安装 |

不做公证、不上架、不做自动更新。
