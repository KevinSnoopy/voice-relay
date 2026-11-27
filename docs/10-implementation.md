# 10 · 实现说明（v0.2）

> 本文件记录代码实际做了什么、跑出了什么、与文档哪里不同。
> 文档 01–09 仍是设计与验收准绳；本文件只描述当前实现。

## 1. 已完成

### Mac 端（`mac/`）

| 模块 | 状态 | 说明 |
|---|---|---|
| 协议帧 | ✅ | `ver/type/seq/len`，增量解析，单帧上限 8192 |
| 认证 | ✅ | 6 位配对码 → HKDF-SHA256 → HMAC(challenge)；设备密钥存 `~/Library/Application Support/VoiceRelay/paired-devices.json`（0600） |
| 传输 | ✅ | TCP `0.0.0.0:8787`，Bonjour `_voicerelay._tcp`，TXT 含 v/mid/port/name；BLE GATT 备用通道 |
| BLE | ✅ 代码 | `CBPeripheralManager` 广播服务，手机写入 → 回环 TCP → 现有协议栈；认证/识别/注入完全复用 |
| 音频 | ✅ | PCM16 + Opus 解码（libopus 静态链接）；16 kHz 单声道 |
| 识别 | ✅ | sherpa-onnx 2.0.3 + SenseVoice Small int8，整段识别，greedy，ITN |
| 注入 | ✅ 代码 / ⚠️ 未授权验证 | AX 写入 → Unicode CGEvent → 剪贴板粘贴，Secure Input 拒绝，失败必进剪贴板 |
| 后端 B | ✅ 代码 | CoreAudio HAL 输出到 BlackHole/SayAll 风格设备；后端切换、缺失时回落 A 并回 `0x50` |
| 控制 | ✅ | 指定 App、所有运行 App 直接枚举/unhide/activate/open-b 置顶、⌘`、激活光标、输入框切换、Enter/Shift+Enter、退格、全选、撤销、复制最近；切换后回传 STATE |
| 菜单栏 App | ✅ | 弹窗、状态/电平/最近文本、设置六分区、权限卡、二维码、配对设备吊销、系统级 App/窗口切换 |
| 悬浮电平窗 | ✅ 代码 | 140×44 非激活面板，跟随鼠标，收音淡入/松手 800 ms 淡出 |
| 开机自启 | ✅ 代码 | `SMAppService.mainApp`，仅 App Bundle 内有效 |
| 首次引导 | ✅ 代码 | 首次启动打开 560×400 窗口；第 3 步必须真的收到音频才可完成 |
| 日志 | ✅ | `~/Library/Logs/VoiceRelay/*.log`，JSONL，保留 3 天，不记文本内容 |
| 命令行 | ✅ | `voicerelayd` 守护进程；`vrphone` 手机模拟端；`--devices` 列出音频设备 |
| 应用图标 | ✅ | `mac/Resources/AppIcon.icns`（16→1024 共 10 档）；`build-app.sh` 拷进 `Contents/Resources/`，`Info.plist` 写 `CFBundleIconFile=AppIcon` |

### 手机端（`mobile/voicerelay/`）

| 模块 | 状态 | 说明 |
|---|---|---|
| 协议 | ✅ 源码 | 帧、HKDF/HMAC、握手、音频、指令，和 Swift 端逐字节一致 |
| 传输抽象 | ✅ 源码 | `RelayTransport`，TCP 与 BLE 共用同一客户端 |
| TCP | ✅ 源码 | 手填 IP/端口/配对码 |
| BLE | ✅ 源码 | `flutter_blue_plus` 扫描、连接、订阅通知、分片写入 |
| 发现 | ✅ 源码 | `multicast_dns` 扫描 `_voicerelay._tcp`；二维码扫描（`mobile_scanner`） |
| 录音 | ✅ 源码 | `record` 插件，PCM16/16 kHz/单声道，40 ms 分包 |
| 界面 | ✅ 源码 | 欢迎、权限、连接（自动发现/蓝牙/扫码）、主屏（按住说话/电平/最近文本/失败原因）、设置、控制面板 |
| 编译验证 | ✅ | `flutter analyze` 无问题；6 个协议/心跳测试通过；Android debug APK 构建成功；真机/iOS 未验 |
| 应用图标 | ✅ | 母版 `tools/icons/render_icon.swift`（Swift + CoreGraphics 矢量绘制）；Android 旧版 PNG（48→192）+ API 26 自适应图标（前景 108→432 + 渐变背景）；iOS `AppIcon.appiconset` 15 档（20→1024），actool 编译通过 |

## 2. 怎么跑

```bash
cd mac
./scripts/install-app.sh
```

安装到 `/Applications/VoiceRelay.app`，优先用本机 Apple Development 证书签名。
**不要直接运行 `build/VoiceRelay.app`**：TCC 按“副本 + 签名”记权限，构建目录副本和 Applications 副本会被当成两个 App。
首次安装或换签名后，执行一次 `tccutil reset Accessibility com.voicerelay.app`，再到「系统设置 › 隐私与安全性 › 辅助功能」勾选 VoiceRelay，并重启 App。
默认只走 AX/Unicode 直接写入光标；不做静默剪贴板降级。需要兼容只支持粘贴的 App 时，在设置 › 语音里手动打开「兼容模式：允许自动粘贴」。

- 蓝牙备用通道：设置 › 连接 › 启用蓝牙备用通道（首次会请求蓝牙权限）。
- 后端 B：先安装 BlackHole 2ch 或 SayAll 风格虚拟声卡，设置 › 语音 › 识别后端选 B。
- 音频设备检查：`cd mac && swift run voicerelayd --devices`。

无界面联调：

```bash
cd mac
swift build
./.build/debug/voicerelayd --pairing-code 123456
# 另一个终端
./.build/debug/vrphone --code 123456 --say "把第三段的标题改短一点，下面两行跟上节奏。"
```

单元测试：

```bash
cd mac && swift test
```

### 授权后仍提示未授权？

macOS 的辅助功能权限按 **App 副本路径 + 代码签名** 记录，不是按 Bundle ID 全局生效：

- 从 `mac/build/VoiceRelay.app` 运行、又从 `/Applications` 授权，会被当成两个 App；
- ad-hoc 签名（`codesign -s -`）每次重建 CDHash 都会变，旧授权立即失效；
- `tccutil reset Accessibility com.voicerelay.app` 会清掉该 Bundle ID 的所有旧记录，需要重新勾选。

现在的 `scripts/install-app.sh` 会优先用本机 Apple Development 证书签名并安装到 `/Applications/VoiceRelay.app`；之后重建只要证书/Bundle ID 不变，授权可以延续。**始终运行 `/Applications` 这一份，不要再打开 `build/` 里的副本。**

## 3. 实测（2026-11-26，本机 Intel / macOS 13.7.8）

S1 关注项：

| 项 | 结果 |
|---|---|
| 模型 | SenseVoice Small int8，239 MB，冷加载约 2 s |
| 8 s 以内音频推理 | 279–313 ms（5.3 s 音频），RTF ≈ 0.05–0.06 |
| 端到端（松手 → RESULT） | 282–377 ms（不含人工授权/注入耗时） |
| 中文结果 | 「把第三段的标题改短一点，下面两行跟上节奏。」「周五下午两点前把方案发我，有问题随时找我。」均逐字正确 |
| 单元测试 | Mac 15 个通过（帧、认证、PCM、指令、BLE UUID、虚拟声卡枚举、IME 未确认语义）；Flutter 6 个协议/心跳测试通过 |
| 注入 | 默认只走 AX/Unicode 直接写入；成功必须回读确认，失败显示「未送达」且不静默复制。当前辅助功能已授权，S3 矩阵仍未完成 |
| BLE / 后端 B / 悬浮窗 / 开机自启 | 代码完成；B 停流只报「已发送·未确认」；未做硬件/驱动验收（S4/S5） |

2026-11-26 状态复核：SenseVoice int8 模型文件存在（约 228 MB），当前运行实例也已加载；重启后可重新加载。Android 模拟器已验证权限、mDNS、认证、STATE、收音、失败保留文本、快速点按不卡死，以及指定 App 置顶后 STATE 同步；隔离 daemon 无辅助功能权限时，⌘Tab 会明确拒绝。关闭模拟器 Wi-Fi 未切断既有 TCP，因此不作为断网结论。

## 4. 与文档的差异

| # | 差异 | 原因 / 影响 |
|---|---|---|
| 1 | 手机 V1 发送 **PCM16**，不是 Opus | 当前 Flutter 工程未引入 Opus 编码；PCM16 16 kHz 约 256 kbps，局域网可用。Mac 端已支持 Opus 解码，后续换编码不改协议 |
| 2 | 控制指令新增 `0x09` 全选、`0x0A` 撤销 | `docs/02` 的 CMD 表只到 `0x08`，但 `docs/03` 控制面板要求 ⌘A/⌘Z；实现按 UI 需求扩展并在两端同步 |
| 3 | Mac 接收缓冲保留整段（上限 60 s），不是 2 s | `docs/02` §7 的 2 s 适用于抖动缓冲；V1 是整段识别，若只留 2 s 会把一句话截断。超过 60 s 才丢最旧并回 `0x21` |
| 4 | BLE 用“GATT → 回环 TCP”桥接，而不是在 BLE 层重写会话 | 认证、ASR、注入完全复用；BLE 只当字节管道。手机仍走完整 HELLO/AUTH，链路语义不变 |
| 4.1 | 默认关闭自动粘贴，失败不静默复制 | 按“文字直接进光标”的产品要求；粘贴改为设置里的兼容模式，默认关闭 |
| 5 | 后端 B 未自动按输入法语音键，且无法确认上屏 | 不同输入法键位不同；当前只写虚拟声卡并切换后端，返回 `ok=false / reason=ime_unconfirmed / path=ime`，手机显示「已发送到输入法」 |
| 6 | 配对码同时用作二维码 `tok` | `docs/02` 的 `tok` 是一次性随机串；V1 为少一个状态，二维码里直接带 6 位配对码，120 s 过期由客户端判断 |
| 7 | 手机只实现功能版界面，不是 13 画板逐像素 | 核心流程完整；M-08/M-09 以主屏结果卡呈现，M-12 排查页尚未单独成页 |

## 5. 目录

```
mac/
  Package.swift
  Sources/
    VoiceRelayCore/    协议、认证、TCP、Bonjour、BLE、ASR、注入、虚拟声卡、控制、日志
    VoiceRelayApp/     菜单栏 App（SwiftUI）、悬浮窗、引导、开机自启
    voicerelayd/       无界面守护进程
    vrphone/           手机模拟端（完整协议）
  Tests/               协议/认证/PCM/指令/BLE/设备枚举测试
  vendor/              sherpa-onnx 2.0.3 osx-x64 + libopus 静态库
mobile/voicerelay/     Flutter 手机端源码（Android 平台目录已生成，iOS 未验证）
tools/icons/            应用图标：render_icon.swift（矢量母版）+ build_icons.sh（各平台产物）
```

## 6. 下一步（按优先级）

1. 在系统设置里给 VoiceRelay 辅助功能权限，跑 `docs/07` 的 S3 注入矩阵。
2. 在目标真机上安装当前 debug APK，验证 iOS/Android 权限、BLE、后台保活与真实录音；模拟器 QEMU 曾在收音时崩溃，不能替代真机结论。
3. 补手机端 M-08/M-09/M-12 独立页面与 Opus 编码。
4. 安装 BlackHole 2ch，跑 S5；开蓝牙跑 S4，确认 10 分钟不积压。
5. S2 公司网络按文档验证 Bonjour / 单播 / BLE 三项。
