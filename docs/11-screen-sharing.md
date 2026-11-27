# 11 · 屏幕共享（只看不控）

> 状态：设计草案 v1.2 · 2026-11-26（补充输入光标跟随、窗口缩略图、Android 10+/iOS 15+、整屏保留）
> 范围：Mac → 手机的单向实时屏幕共享。手机只看，不控制 Mac。
> 关联：[01-architecture.md](01-architecture.md)、[02-protocol.md](02-protocol.md)、[03-ui-mobile.md](03-ui-mobile.md)、[04-ui-mac.md](04-ui-mac.md)、[05-permissions-onboarding.md](05-permissions-onboarding.md)、[07-validation-plan.md](07-validation-plan.md)、[08-risks.md](08-risks.md)、[09-decisions.md](09-decisions.md)。

---

## 0. 一句话

手机像看直播一样看 Mac 当前窗口：**720p、30fps、局域网、无声音、无远程控制**；默认跟随“文本光标所在 App 的窗口”，可在手机上手动切换窗口，也保留整屏模式。

---

## 1. 结论

| 项 | 结论 |
|---|---|
| 是否可行 | **可行**。ScreenCaptureKit 采集 + WebRTC H.264 硬件编码 + Flutter 播放，链路成熟 |
| 本机采集 | macOS 13.7.8，ScreenCaptureKit 可用；`SCScreenshotManager` 是 macOS 14+，本期用 `SCStream` |
| 本机编码 | H.264 硬件编码可用；HEVC 只有软件编码，**本期不用 HEVC** |
| 目标画质 | 1280×800（16:10，俗称 720p 档）· 30fps · 1.5–2.5 Mbps |
| 目标延迟 | 玻璃到玻璃 P95 < 300 ms，典型 100–250 ms |
| 传输 | WebRTC P2P，仅局域网；信令走现有 8787，媒体走 UDP/DTLS-SRTP |
| 手机端 | Android 先做，iOS 同步实现；共用协议与 UI 规格 |
| 音频 | **不做**。没有系统声音、没有麦克风、没有音频轨道 |
| 控制 | **不做**。没有远程点击、键盘、剪贴板、文件传输 |
| 默认窗口 | **跟随文本光标所在窗口**；识别失败时退回前台 App 窗口；手机可手动切换 |
| 权限 | macOS“屏幕录制”必需；跟随光标复用现有“辅助功能”，不新增权限；iOS 只需本地网络 |
| 手机版本 | iOS 15+；Android 10+（API 29） |

### 1.1 本机压测（2026-11-26）

MacBook Pro 11,2 / i7-4770HQ / Iris Pro / macOS 13.7.8，用 VideoToolbox 合成画面压测：

| 分辨率 | 编码耗时 | 折合帧率 | 硬件编码 |
|---|---:|---:|---|
| 1280×800 | 3.3 ms/帧 | ~305 fps | ✅ |
| 1920×1200 | 5.6 ms/帧 | ~177 fps | ✅ |
| 1920×1080 | 5.2 ms/帧 | ~193 fps | ✅ |

30fps 每帧预算 33 ms，720p 编码只占约 3.3 ms，**余量约 10 倍**。该数据只证明编码器吞吐，不含 ScreenCaptureKit 采集、缩放、WebRTC 和真实 Wi-Fi 抖动；S6 必须端到端复测。

### 1.2 当前网络

- Wi-Fi：802.11ac，5GHz，80MHz，PHY 867 Mbps，信号 -51 dBm。
- 720p30 按 2 Mbps 计算，不到 PHY 的 0.3%；实际瓶颈不在带宽，而在 Wi-Fi 抖动、AP 负载和 Mac 采集稳定性。

### 1.3 输入光标跟随：可行，但是“最佳努力”

可以做到，但 macOS **没有公开 API 直接返回“哪个窗口拥有文本光标”**。可行路径是：

1. 通过 Accessibility 取系统级 `AXFocusedUIElement`。
2. 从焦点元素向上找到所属 `AXWindow`，读 PID、标题、位置、尺寸。
3. 用 PID + 标题 + 窗口矩形匹配 `SCShareableContent.windows`，得到可捕获的 `SCWindow`。

VoiceRelay 已经为文本注入申请了辅助功能，所以**不新增权限**；但这条路径依赖辅助功能，且不是 100% 可靠。

| 情况 | 行为 |
|---|---|
| Safari / Chrome / VSCode / 飞书 / 微信等标准 App | 通常能正确识别焦点窗口 |
| 焦点在 sheet / 查找栏 / 弹出层 | 优先共享其顶层父窗口，避免只看到一条小浮层 |
| Electron / Java / 游戏 / 自绘界面 | AX 信息可能不完整，退回前台 App 窗口 |
| Finder 桌面、没有文本光标 | 退回前台 App 窗口 |
| Secure Input / 密码框 | AX 焦点可能不可读；退回前台窗口，并按隐私规则暂停或模糊 |
| 辅助功能未授权 | 屏幕共享仍可用，但只能退回前台 App 窗口；UI 提示“无法精确跟随光标” |

结论：**默认跟随焦点窗口，失败自动退回前台窗口，绝不因为跟随失败而让共享不可用。**

---

## 2. 已确认决策

| 编号 | 决策 | 说明 |
|---|---|---|
| S-01 | **720p30 足够** | 目标 1280×800 / 30fps；不追求 1080p、60fps。网络差时降帧率优先，保分辨率 |
| S-02 | **默认跟随输入光标** | 默认共享包含文本光标的 App 窗口；手机可手动切换；手动选择后暂停跟随；“整屏”保留为次要选项 |
| S-03 | **仅局域网** | 不做跨互联网中继、不做 BLE 视频；与项目“明确不做跨互联网中继”一致 |
| S-04 | **Android 先做，iOS 也要做** | 共用协议、状态机和 UI 规格；iOS 后补真机验证 |
| S-05 | **不做系统声音** | 不创建音频轨道，不申请麦克风；避免和现有录音链路冲突 |
| S-06 | **只看不控** | 不做 CGEvent、键盘注入、剪贴板、文件传输 |
| S-07 | **权限最小化** | 新增 macOS“屏幕录制”和 iOS“本地网络”；跟随光标复用现有辅助功能，不新增权限；AX 不可用时退回前台窗口 |
| S-08 | **版本基线** | iOS 15+；Android 10+（API 29）；整屏模式保留 |
| S-09 | **窗口缩略图** | 选择器显示 72×45 缩略图；仅选择器打开时生成；AES-GCM 分片传输；失败回退 App 图标 |

> S-01…S-09 是本功能的产品决策；是否升级为全局 D-13…D-18，见 §18。

---

## 3. 目标与非目标

### 3.1 目标

| 目标 | 衡量方式 |
|---|---|
| 像共享屏幕一样持续观看 | 720p30 连续 30 分钟，丢帧 < 2% |
| 默认窗口正确 | 在 Safari / Chrome / VSCode / 飞书 / 微信中，文本光标所在窗口识别成功；失败时前台窗口兜底 |
| 打开就能看 | 点击到首帧 < 2 s；窗口切换 < 1.5 s |
| 文字可读 | 1280×800 下，手机横屏全屏可读正文；双指放大后 1:1 可读小字 |
| 不打扰 Mac 使用者 | 菜单栏有共享指示，可一键停止；不抢焦点、不改系统设置 |
| 不拖慢语音链路 | 共享期间语音端到端 P95 仍 < 1 s；Mac CPU 增量 < 20% |
| 隐私可控 | 默认窗口、按次开启、自动停止、不落盘、不上云 |

### 3.2 非目标

- 远程控制 Mac（点击、键盘、拖拽、剪贴板）。
- 系统声音、麦克风、通话。
- 4K、60fps、HDR、多路同时观看。
- 跨互联网、4G/5G 直连、自建中继。
- 录屏、回放、截图历史、OCR。
- 多台 Mac、多台手机、账号体系。
- 画中画（PiP）和后台持续播放（V1 不做）。

---

## 4. 体验规格

### 4.1 入口

- **手机主屏**：右上角设置图标左侧新增“共享屏幕”图标（显示器轮廓）。仅在已连接、Mac 端可用时点亮。
- **控制面板**：底部新增“共享屏幕”按钮，和切 App、回车等并列。
- **Mac 菜单栏**：共享开始后图标叠加小屏幕标记；弹窗显示“正在共享：Safari — 项目文档”与“停止共享”。
- 首次点击弹出“选择窗口”底部抽屉，不直接开始共享。

### 4.2 窗口选择器

底部抽屉，标题“选择要共享的窗口”：

| 元素 | 规格 |
|---|---|
| 跟随开关 | 顶部“跟随输入光标”开关，默认开；手动选择窗口后自动关闭 |
| 当前窗口 | 置顶，标记“跟随中”；文本光标所在 App 的窗口；无文本光标时用前台 App 窗口 |
| 缩略图 | 左侧 72×45、圆角 6；加载中骨架；失败/受保护窗口用 40×40 App 图标 |
| 列表行 | 缩略图（或 App 图标）+ App 名 14/600 + 窗口标题 12/400 灰色 + 尺寸；右侧“共享” |
| 排序 | 跟随中/当前窗口优先，其余按窗口前后顺序 |
| 刷新 | 右上角“刷新”；打开时自动拉一次 |
| 整屏 | 列表底部次要入口“改为共享整个屏幕”；保留，但需二次确认 |
| 空态 | “没有可共享的窗口。请先在 Mac 上打开一个窗口。”+ 刷新 |
| 加载态 | 3 行骨架，不阻塞返回 |

手动选择任意窗口后，`follow` 自动置为 false；用户可在观看页或选择器重新打开“跟随输入光标”。

缩略图生成、缓存和传输见 §6.2；选择器关闭即释放，不落盘。

### 4.3 观看页

| 项 | 规格 |
|---|---|
| 方向 | 进入时允许横屏；退出恢复竖屏 |
| 画布 | 黑底，16:10 等比适应；非 16:10 窗口加黑边 |
| 手势 | 双指缩放 1–4×；拖动平移；双击在“适应屏幕”和“1:1”之间切换 |
| 顶部 | 返回、窗口标题、绿点“实时”、fps / 延迟；3 秒自动隐藏，点按唤出 |
| 跟随状态 | 标题旁显示“跟随光标”或“已手动锁定”；点击可切换；切换后 toast：“已恢复跟随”/“已暂停跟随” |
| 底部 | 暂停/继续、切换窗口、停止；3 秒自动隐藏 |
| 标识 | 左上角“只看不控”胶囊，避免误以为可以操作 |
| 常亮 | 观看期间屏幕常亮；退出恢复系统设置 |
| 音频 | 无音量按钮、无静音按钮 |

### 4.4 状态

| 状态 | 手机表现 | Mac 表现 |
|---|---|---|
| 连接中 | “正在建立屏幕连接…”+ 取消 | 菜单栏图标出现共享标记 |
| 等待授权 | “需要在 Mac 上允许屏幕录制”+ 步骤 | 设置页权限卡高亮 |
| 实时 | 绿点、fps、延迟；画面 | 菜单栏共享标记 |
| 自动跟随 | 顶部 toast“已跟随到 Safari — 项目文档”，不打断观看 | 切换 SCStream |
| 跟随失败/回退 | 顶部小提示“无法读取光标，已使用前台窗口”；可手动选择 | 记录原因，不阻断共享 |
| 切换中 | 保留最后一帧 + “正在切换窗口…” | 重建 SCStream |
| 暂停 | 最后一帧模糊/压暗 + “已暂停” | 菜单栏仍显示共享，可停止 |
| Mac 锁屏/睡眠 | “Mac 已锁屏/睡眠，唤醒后自动恢复” | 捕获停止 |
| 窗口关闭/最小化 | “窗口已关闭/最小化”+ 重新选择 | 流停止或最后一帧 |
| 网络断开 | “连接中断，正在重连（1/3）” | 等待 ICE 恢复 |
| 权限被撤销 | “屏幕录制权限已被关闭”+ 去 Mac 设置 | 流停止，权限卡变黄 |
| 正常结束 | 返回主屏 | 菜单栏恢复普通态 |

### 4.5 Mac 端

- **设置新增第七分区“屏幕共享”**：
  - 默认范围：跟随输入光标（默认）/ 上次窗口 / 整个屏幕。
  - 跟随输入光标：默认开；手动选择窗口后暂停；焦点变化 300–500 ms 防抖后再切换。
  - 最大帧率：30 / 15。
  - 自动停止：30 分钟（默认开）/ 10 分钟 / 从不。
  - 允许共享整个屏幕：默认开（保留），但手机端整屏入口需二次确认。
  - 权限卡：屏幕录制（未授权 / 已授权 / 需重启 / 被 MDM 锁定）；辅助功能显示“用于精确跟随光标”，未授权时降级但不阻断。
  - 跟随失败提示：可关闭“跟随失败时提示”，默认开。
- **菜单栏弹窗**：显示当前共享窗口标题、已共享时长、停止按钮；不做缩略图。
- **系统指示**：macOS 自带屏幕录制指示保留，不隐藏、不绕过。
- **不抢焦点**：共享开始/停止不激活其他 App，不改变前台窗口。

---

## 5. 架构

```
Mac（VoiceRelay.app）                                   Phone（Flutter）
┌──────────────────────────────────┐                  ┌──────────────────────────┐
│ WindowCatalog                    │                  │ ScreenViewer             │
│  SCShareableContent.windows      │  8787 信令        │  窗口选择 / 状态机        │
│  ↑ FocusTracker（AX 焦点窗口）    │ ←──────────────→ │  横屏 / 缩放 / 状态条     │
│  ↓ 窗口列表（JSON，含 focused）    │                  │  跟随开关                │
│ ScreenSession                    │                  │                          │
│  SCStream(window filter)         │  UDP/DTLS-SRTP   │  flutter_webrtc          │
│  ↓ CVPixelBuffer                 │ ───────────────→ │  RTCVideoRenderer        │
│  RTCVideoSource → H.264 硬编     │   720p30 媒体     │  H.264 硬解 → RTCVideoView│
│  ↓                               │                  │                          │
│ WebRTC PeerConnection            │                  │                          │
│ PrivacyGuard / AutoStop          │                  │  只看不控                 │
└──────────────────────────────────┘                  └──────────────────────────┘
```

### 5.1 模块职责

| 模块 | 端 | 职责 | 关键 API |
|---|---|---|---|
| `WindowCatalog` | Mac | 枚举可共享窗口、过滤、排序、提供 App 图标 | `SCShareableContent.windows`、`NSRunningApplication` |
| `FocusTracker` | Mac | 读系统焦点元素/焦点窗口，匹配 SCWindow；监听焦点变化 | `AXUIElementCreateSystemWide`、`kAXFocusedUIElementAttribute`、`AXObserver` |
| `ScreenSession` | Mac | 会话状态机、窗口切换、跟随策略、自动停止、错误映射 | `SCStream`、`SCContentFilter` |
| `ScreenSource` | Mac | 把 SCK 帧转成 WebRTC 视频帧 | `RTCVideoSource`、`RTCVideoCapturer` |
| `ScreenSignal` | 两端 | 窗口列表、开始/切换/停止、SDP/ICE 信令 | 8787 `CMD 0x0F` |
| `PrivacyGuard` | Mac | 排除自身窗口、Secure Input 暂停、超时停止 | `SCContentFilter`、现有 Secure Input 检测 |
| `ScreenViewer` | 手机 | 窗口选择、观看页、状态、统计 | `flutter_webrtc`、`RTCVideoView` |

### 5.2 数据流

1. Mac 的 `FocusTracker` 解析文本光标所在窗口；`SCREEN_LIST` 中标记 `focused: true`。
2. 手机发 `SCREEN_LIST_REQ`。
3. Mac 返回窗口列表（ID、App 名、标题、尺寸、是否焦点窗口、是否当前共享）。
4. 手机发 `SCREEN_START {windowId, follow:true, width:1280, height:800, fps:30}`；不传 `windowId` 时用焦点窗口。
5. Mac 创建 `SCStream`，把帧推给 `RTCVideoSource`；双方通过 8787 交换 SDP/ICE。
6. 媒体走 UDP/DTLS-SRTP；手机 `RTCVideoView` 渲染。
7. 切换窗口：手机发 `SCREEN_SWITCH {windowId, follow:false}`；Mac **只重建 SCStream 和过滤器，不重建 PeerConnection**，视频轨道不变。
8. 焦点变化且 `follow:true`：Mac 在 300–500 ms 防抖后自动切换；手机收到 `SCREEN_STATE {follow:true, windowId}`。
9. 停止：`SCREEN_STOP`；关闭 PeerConnection、停止 SCStream、恢复菜单栏状态。

---

## 6. Mac 采集

### 6.1 窗口列表

- 用 `SCShareableContent.windows` 获取窗口。
- 过滤规则：
  - `windowLayer == 0`（排除菜单栏、Dock、悬浮层）。
  - `frame.width >= 200 && frame.height >= 120`。
  - 排除 VoiceRelay 自己的窗口（bundle ID / owningApplication）。
  - 排除标题为空且 App 名为空的窗口。
  - 排除已知系统窗口（如 Window Server、控制中心）可后续按 bundle ID 黑名单补充。
- 排序：
  - 前台 App（`NSWorkspace.shared.frontmostApplication`）的窗口置顶。
  - 其余用 `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)` 的顺序判断前后；`kCGWindowNumber` 与 `SCWindow.windowID` 对应。
- 当前窗口：**文本光标所在窗口**（见 §6.6）；无法解析时退回前台 App 的第一个满足过滤条件的窗口；如果前台是 VoiceRelay，则取上一个可共享窗口，或要求用户选择。
- 列表项带 `focused` 标记；选择器顶部“跟随输入光标”开关默认开。
- App 图标：`NSRunningApplication(processIdentifier:).icon`，转 28×28 PNG。
- 列表刷新：打开选择器时拉一次；切换失败/窗口关闭时再拉一次。观看中不轮询，避免无谓开销。

### 6.2 窗口缩略图（V1 必做）

#### 6.2.1 目标

选择器每行显示 72×45 缩略图；加载时先出骨架；失败、最小化、DRM 或受保护窗口退回 App 图标。缩略图只用于选择，不参与视频流。

#### 6.2.2 采集

| 系统 | API | 说明 |
|---|---|---|
| macOS 14+ | `SCScreenshotManager.captureImage(contentFilter:configuration:)` | 首选，异步、现代 |
| macOS 13 | `CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .bestResolution])` | 已废弃但本机可用；隔离在 `ThumbnailProvider`，不扩散到其他模块 |

- 输入 `SCWindow.windowID`；输出 320×200（2x，用于 160×100 显示），JPEG q0.6，约 8–20 KB。
- 只对前 12 个候选窗口生成；列表滚动到更多时再按需生成。
- 选择器打开时生成，关闭即清空；缓存 5 s，窗口标题或尺寸变化则失效。
- 并发上限 2，后台队列执行；不在主线程同步截图，避免列表卡顿。
- 被遮挡窗口通常仍可截；最小化/DRM/受保护窗口可能为空或黑图，直接退回 App 图标。
- 生成前排除 VoiceRelay 自身窗口；缩略图不包含光标，`showsCursor = false`。

#### 6.2.3 传输与加密

缩略图是真实屏幕内容，**不能明文塞进窗口列表 JSON**。

1. 整张 JPEG 用会话密钥派生的 `thumbKey = HKDF(sessionKey, "thumb-v1")` 做 AES-GCM 加密。
2. 密文按 ≤ 2 KB 分片，base64 后约 2.7 KB，确保单帧 < 4096，不触碰全局帧上限。
3. `thumb_begin` 带 `nonce`、`tag`、`total`、`len`；手机按 `thumbId` 重组后解密、校验长度。
4. 只发给已认证的配对设备；选择器关闭或会话结束时立即释放内存，不落盘、不写日志。

#### 6.2.4 UI 行为

- 列表先返回文本信息，缩略图后到；不让截图阻塞“选择窗口”。
- 收到缩略图后淡入 100 ms；同一窗口重复打开优先用 5 s 缓存。
- 失败不显示破图，直接显示 App 图标；不弹错误。
- 缩略图比例按 16:10 裁切/留黑边，不拉伸。
- 选择器关闭时取消未完成截图，释放 `CGImage`/JPEG 缓冲。

### 6.3 SCStream 配置

| 项 | 值 | 说明 |
|---|---|---|
| 过滤器 | `SCContentFilter(desktopIndependentWindow: window)` | 窗口被遮挡仍可捕获；最小化/关闭除外 |
| 输出尺寸 | 1280×800 | 16:10；非 16:10 窗口等比适配 + 黑边 |
| 像素格式 | 优先 NV12（420f/420v），JPEG 兜底用 BGRA | WebRTC 直接用 NV12，少一次转换 |
| 帧率 | `minimumFrameInterval = 1/30 s` | 网络差时动态改 1/15、1/10 |
| 队列 | `queueDepth = 3` | 编码器忙就丢最旧帧 |
| 光标 | `showsCursor = true` | 窗口捕获下光标是否出现需 S6 验证 |
| 音频 | `capturesAudio = false` | 不做声音 |
| 缩放 | `scalesToFit = true`，保持宽高比 | 若 SDK 属性不可用，手动计算目标矩形 |
| 背景 | 不透明黑底 | 窗口透明区域不露桌面 |

### 6.4 窗口切换与异常

- **切换**：停止旧 `SCStream` → 创建新 filter/stream → 启动 → 等首帧 → 手机撤掉“切换中”。目标 < 1.5 s。
- **保留最后一帧**：切换期间手机继续显示旧帧，避免黑屏；新帧到达后替换。
- **窗口 resize**：输出固定 1280×800，等比适配；不重启流。
- **窗口关闭**：`SCStreamDelegate.stream(_:didStopWithError:)` 或窗口列表复查发现消失；手机提示“窗口已关闭”，提供重新选择。
- **窗口最小化**：`isOnScreen` 变 false；暂停并提示；恢复后重新开始。
- **窗口跨显示器**：窗口捕获不依赖显示器；整屏模式才需要选择显示器。
- **显示器热插拔/分辨率变化**：整屏模式重建流；窗口模式通常不受影响。
- **Mac 锁屏/睡眠**：捕获停止；唤醒后如果会话仍在，自动重连一次，失败则结束。

### 6.5 整屏模式（次要）

- `SCContentFilter(display:excludingWindows:)`，排除 VoiceRelay 窗口。
- 输出 1280×800，16:10；其他比例加黑边。
- 整屏会包含菜单栏、Dock、通知、其他 App；手机端必须二次确认，并显示“整屏可能包含敏感内容”。
- 默认可用，但手机端入口折叠；Mac 设置可关闭整屏入口。

### 6.6 输入光标窗口跟随（默认）

#### 6.6.1 目标

共享会话默认选择“**包含文本光标的顶层窗口**”，而不是简单取前台 App 的主窗口。用户在 Safari 地址栏、VSCode 编辑器、飞书输入框里说话时，手机应看到同一个窗口。

#### 6.6.2 解析算法（最佳努力）

1. `AXUIElementCreateSystemWide()` 创建系统级元素。
2. 读 `kAXFocusedUIElementAttribute` 得到当前焦点元素。
3. 若焦点元素本身就是窗口，直接用它；否则沿 `kAXParentAttribute` 向上找到 role 为 `AXWindow` 的祖先。
4. 读该窗口的 `kAXTitleAttribute`、`kAXPositionAttribute`、`kAXSizeAttribute`，并用 `AXUIElementGetPid` 取 PID。
5. 在 `SCShareableContent.windows` 中匹配：同一 PID + 标题相同或包含 + 窗口矩形误差在 S6 校准的容差内（初始 8 pt）；必要时用 `CGWindowListCopyWindowInfo` 的窗口顺序/标题辅助消歧。
6. 匹配到 `SCWindow` 后，用它创建 `SCContentFilter(desktopIndependentWindow:)`。

> macOS 没有公开 API 直接把 AX 窗口转成 `CGWindowID`。不要依赖私有 `_AXUIElementGetWindow`；用 PID + 标题 + 矩形匹配，失败就走降级。

#### 6.6.3 边界规则

| 情况 | 处理 |
|---|---|
| 焦点在 sheet / 查找栏 / 弹出层 | 向上找顶层父窗口；避免共享一条窄浮层 |
| 同一 App 多个窗口 | 优先标题匹配；标题相同则用矩形匹配；仍不唯一则取前台/key window |
| 焦点在菜单、Dock、通知 | 不跟随；保持当前窗口 |
| 焦点在 VoiceRelay 自己 | 不跟随；保持上一个可共享窗口或提示选择 |
| Finder 桌面、无文本光标 | 退回前台 App 窗口 |
| Electron / Java / 游戏 / 自绘界面 | AX 信息不完整；退回前台 App 窗口 |
| Secure Input / 密码框 | 不读取内容；暂停跟随，保持当前窗口；按隐私规则模糊/暂停 |
| 辅助功能未授权 | 不阻断共享；退回前台 App 窗口，UI 提示“无法精确跟随光标” |

#### 6.6.4 通知与防抖

- 用 `AXObserver` 监听当前 App 的 `kAXFocusedUIElementChangedNotification` / `kAXFocusedWindowChangedNotification`；用 `NSWorkspace.didActivateApplicationNotification` 处理 Cmd+Tab，再补一次焦点解析。
- 焦点变化后 **300–500 ms 防抖**，只对稳定的顶层窗口切换；菜单、tooltip、popover 的瞬时焦点不触发。
- 以下情况暂停自动跟随：
  - 用户手动选择了窗口（`follow=false`）。
  - 观看页暂停、切换窗口弹层打开、手机切后台。
  - 正在执行一次窗口切换（避免连切）。
  - Secure Input 或隐私暂停生效。
- 自动切换前先确认新窗口在 `SCShareableContent.windows` 中且可捕获；失败则保持当前窗口，发一条 `warning`，不弹模态。
- 切换成功后手机 toast“已跟随到 Safari — 项目文档”，不打断观看。

#### 6.6.5 手动覆盖

- 选择器里手动选任意窗口 → `follow=false`，标题旁显示“已手动锁定”。
- 观看页/选择器重新打开“跟随输入光标” → 立刻解析一次焦点窗口；成功则切换，失败则退回前台窗口并提示。
- 手动锁定不因焦点变化而自动解除；只有用户显式恢复跟随，或重新开始会话。

#### 6.6.6 性能与隐私

- AX 查询放后台队列，最多 2 Hz；不在每帧回调里查。
- 缓存窗口列表 1–2 s；焦点变化时只做增量匹配。
- 只读窗口/PID/标题/矩形，不读文本框内容、不读选中文字、不做 OCR。
- 窗口标题只用于当前会话匹配，不写入长期日志。

---

## 7. 编码

### 7.1 选型

| 项 | 选择 | 理由 |
|---|---|---|
| 编码 | **H.264 硬件编码** | 本机 `hw=true`；HEVC 只有软件，会和 ASR 抢 CPU |
| 分辨率 | 1280×800 | 16:10，720p 档；文字和带宽平衡 |
| 帧率 | 30fps | 共享屏幕的基本流畅度 |
| 码率 | 1.5–2.5 Mbps | 5GHz 局域网余量很大；文字边缘需要码率 |
| 关键帧 | 1 秒 | 丢包/切换后快速恢复 |
| B 帧 | 关闭 | 降延迟 |
| 音频 | 无 | 不创建音频轨道 |

### 7.2 WebRTC 编码路径

- 用 `RTCVideoSource` + 自定义 `RTCVideoCapturer`，把 SCK 的 `CVPixelBuffer` 推给 WebRTC。
- `adaptOutputFormatToWidth:height:fps:` 设 1280×800 / 30；让 WebRTC 做缩放和码率控制。
- `RTCRtpTransceiver.setCodecPreferences` 优先 H.264（Main/Baseline），Android 不支持时 VP8 兜底。
- S6b 必须确认实际走的是 **VideoToolbox 硬编**，不是 OpenH264 软编；如果 WebRTC 构建不带硬编，退回 `VTCompressionSession` 自编 + 自定义发送。

### 7.3 自适应策略

优先级从高到低：

1. **保分辨率**：1280×800 不变。
2. **降帧率**：30 → 15 → 10。
3. **降码率**：2.2 → 1.5 → 1.0 Mbps。
4. **最后降分辨率**：1280×800 → 960×600。

屏幕共享里文字清晰度比运动流畅度重要；不要一掉帧就把分辨率砍到 480p。

### 7.4 编码失败

- 硬件编码不可用：回退软件 H.264，UI 提示“性能可能下降”。
- H.264 协商失败：回退 VP8；Android 软解可能发热，提示用户。
- 编码持续失败：停止共享，回传 `SCREEN_ERROR_ENCODER`，保留语音功能。

---

## 8. 传输与信令

### 8.1 原则

- **信令走 8787**：复用现有 HELLO/AUTH/CMD/STATE、配对、HMAC 会话。
- **媒体走 WebRTC UDP**：DTLS-SRTP；局域网 P2P，不经过 8787。
- **视频绝不上 BLE**：BLE 20–30 kbps，差两个数量级。
- **不做 TURN/中继**：仅局域网；跨网段/公司隔离直接报错。

### 8.2 信令消息

新增 `CMD 0x0F SCREEN`，payload 为紧凑 JSON：

| `op` | 方向 | 内容 |
|---|---|---|
| `list_req` | 手机 → Mac | 请求窗口列表 |
| `list` | Mac → 手机 | `[{id, app, title, w, h, focused, current, hasThumb}]` |
| `thumb_begin` | Mac → 手机 | `{id, w, h, mime, total, len, nonce, tag}`；JPEG 密文元信息 |
| `thumb_chunk` | Mac → 手机 | `{id, idx, total, data}`；`data` 为 base64 密文分片，≤ 2 KB 原文 |
| `thumb_end` | Mac → 手机 | `{id}`；手机重组、解密、校验后显示 |
| `start` | 手机 → Mac | `{windowId?, follow, width, height, fps}`；`windowId` 省略时用焦点窗口 |
| `started` | Mac → 手机 | `{streamId, codec, width, height, fps, windowId}` |
| `switch` | 手机 → Mac | `{windowId, follow}`；手动选择时 `follow:false` |
| `follow` | 手机 → Mac | `{enabled}`；恢复/暂停自动跟随 |
| `stop` | 手机 → Mac | 无 |
| `state` | Mac → 手机 | `{state, windowId, focusedWindowId, follow, fps, bitrate, rtt, dropped, warning?}` |
| `offer` / `answer` | 双向 | `{sdp}` |
| `ice` | 双向 | `{candidate, sdpMid, sdpMLineIndex}` |
| `error` | Mac → 手机 | `{code, message}` |

### 8.3 SDP 分片

现有控制帧 payload 上限文档写 4096（实现解析器 8192）。WebRTC SDP 可能超过 4096，必须二选一：

- **A（推荐）**：`0x0F` 信令单独支持分片：`{sid, idx, total, data}`，总长上限 32 KB；只在已认证会话内允许。
- **B**：把控制帧上限临时提高到 16 KB；影响所有消息的解析边界，需回归测试。

V1 建议 A，避免改动全局帧上限。

### 8.4 ICE 与网络

- 仅 host candidate；不配置 STUN/TURN。
- macOS WebRTC 可能对 host candidate 做 mDNS 混淆；S6b 验证 Android/iOS 能否解析。不能解析时关闭 mDNS 或直接按 IP 信令。
- 媒体 UDP 端口为临时端口；macOS 应用防火墙首次可能弹窗，需允许。
- 公司 EDR/防火墙若拦 UDP，报 `SCREEN_ERROR_NETWORK`；V1 不做 TCP/TURN 兜底。
- ICE 断开：重连 3 次（每次 2 s），失败则结束会话并提示。

### 8.5 安全

- 信令必须走现有 HMAC 认证会话；未认证连接不能发 `SCREEN_*`。
- DTLS-SRTP 负责媒体加密；SDP 中的 fingerprint 通过已认证信令传递。
- 配对吊销后，新的 `SCREEN_START` 直接拒绝；已建立会话在 5 s 内关闭。
- 不记录媒体内容、不记录窗口标题到长期日志；只记录状态、字节数、错误码。

---

## 9. 手机端

### 9.1 平台基线

| 项 | Android | iOS |
|---|---|---|
| 优先级 | **先做** | 同步实现，后真机验证 |
| 最低版本 | **Android 10+（API 29）**，项目显式设置 `minSdk = 29` | **iOS 15+** |
| 工程状态 | 已有 `android/`，debug APK 已构建 | **当前没有 `ios/` 目录，需要生成** |
| 解码 | H.264 硬解优先，VP8 兜底 | H.264 硬解 |
| 权限 | INTERNET、ACCESS_NETWORK_STATE | 本地网络 |
| 后台 | 前台使用；后台停止 | 后台挂起；后台停止 |
| 构建 | `flutter build apk` | Xcode 15.2 当前；iOS 18 真机需升级（Q-03） |

### 9.2 依赖

- `flutter_webrtc`：视频渲染、H.264 解码、ICE/DTLS。
- 不引入 `camera`、`microphone`、`audio_session` 相关依赖；不创建音频轨道。
- Android 需确认 `flutter_webrtc` 与当前 AGP/Gradle 版本兼容；iOS 需 `pod install`。
- 若插件体积/构建时间不可接受，备选是平台通道 + `AVSampleBufferDisplayLayer` / `MediaCodec`，但工作量翻倍，不作为首选。

### 9.3 观看页实现

- `RTCVideoRenderer` + `RTCVideoView`；`objectFit: contain`。
- 外层 `InteractiveViewer`：`minScale: 1.0`、`maxScale: 4.0`；双击切换 `1.0` / `2.0`。
- 横屏：进入时 `SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])`；退出恢复 `portraitUp`。
- 常亮：`WakelockPlus` 或平台通道；退出恢复。
- 状态条：`RTCPeerConnection.getStats()` 取 `inbound-rtp` 的 `framesPerSecond`、`frameWidth`、`frameHeight`、`packetsLost`、`jitter`；1 s 刷新一次。
- 缩略图：列表先出文本，`thumb_*` 到达后替换骨架；失败显示 App 图标；不缓存到磁盘，选择器关闭即释放。
- 跟随状态：顶部显示“跟随光标/已手动锁定”；自动跟随时 toast“已跟随到 …”；手动切换后自动置为 `follow=false`。
- 跟随失败提示：顶部一行“无法读取光标，已使用前台窗口”，3 秒后消失；不阻断观看。
- 帧率/延迟显示：延迟优先用应用层时间戳估算；WebRTC 的 `jitterBufferDelay` 可作参考。不要伪造数据。
- 画面比例：容器按 16:10 计算，外部黑边；窗口实际比例不同则 `BoxFit.contain`。
- 切换窗口：保留最后一帧，叠加“正在切换”；新帧到达后淡入 150 ms。

### 9.4 与语音的关系

- 屏幕共享和按住说话可以同时存在，但**录音优先**：
  - 检测到按住说话，屏幕流降到 15fps，持续到松手后 2 s。
  - 不暂停视频，避免用户看不到上下文；如果 Mac CPU 告警，则暂停视频。
- iOS 不创建音频轨道，避免 WebRTC 激活音频会话；S6 要验证“共享时按住说话，录音不被打断”。
- 手机切后台/锁屏：立即停止共享并释放渲染资源；回到前台需重新开始。

### 9.5 Android 专项

- **最低 Android 10（API 29）**；在 `android/app/build.gradle.kts` 显式写 `minSdk = 29`，不要依赖 Flutter 默认值。
- 确认目标机型（Q-02）的 H.264 硬解能力；`MediaCodec` 不支持的机型回退 VP8。
- 不要在 `AndroidManifest.xml` 声明 `CAMERA`/`RECORD_AUDIO`；只加网络权限。
- 前台服务不需要：观看页保持前台；锁屏/切后台停止。
- 屏幕常亮用 `FLAG_KEEP_SCREEN_ON` 或插件；退出清理。
- 旋转时不要重建 `RTCVideoRenderer`；用 `OrientationBuilder` + 固定 renderer。

### 9.6 iOS 专项

- **最低 iOS 15**；先生成 `ios/`：`flutter create --platforms=ios .`；设置 deployment target 15.0。
- `Info.plist`：
  - `NSLocalNetworkUsageDescription`：用于连接同一局域网内的 Mac。
  - `NSBonjourServices`：`_voicerelay._tcp`。
  - 不添加 `NSCameraUsageDescription` / `NSMicrophoneUsageDescription`，除非插件强制要求；先验证。
- `flutter_webrtc` 的 pod 与 Xcode 15.2 兼容性需验证；iOS 18 真机需要更高 Xcode（Q-03）。
- 后台/锁屏停止；V1 不做 PiP。
- 验证 H.264 硬解、横屏、安全区、刘海遮挡。

---

## 10. 延迟与带宽

### 10.1 延迟预算

| 阶段 | 估算 |
|---|---:|
| SCK 采集 | 5–15 ms |
| 缩放/像素转换 | 2–8 ms |
| H.264 硬编 | 3–8 ms（720p） |
| 网络（5GHz 局域网） | 3–15 ms |
| WebRTC 抖动缓冲 | 20–80 ms |
| 手机硬解 | 5–15 ms |
| 显示 | 16–33 ms |
| **合计** | **约 80–200 ms；目标 P95 < 300 ms** |

- 30fps 帧间隔 33 ms；主要变量是 Wi-Fi 抖动和 jitter buffer。
- 不要为了追求 <100 ms 把 jitter buffer 调到极小；画面会因 Wi-Fi 抖动频繁卡顿。
- 测量方法：Mac 上显示毫秒时钟，手机播放同一画面，用 60fps 相机同时拍 Mac 和手机，逐帧差即玻璃到玻璃延迟。

### 10.2 带宽与流量

| 档位 | 码率 | 10 分钟流量 | 30 分钟流量 |
|---|---:|---:|---:|
| 720p30 | 1.5–2.5 Mbps | 110–190 MB | 340–560 MB |
| 720p15 | 1.0–1.5 Mbps | 75–110 MB | 225–340 MB |
| 720p10 | 0.8–1.2 Mbps | 60–90 MB | 180–270 MB |

仅局域网，不走蜂窝；但 Wi-Fi 流量仍会计入路由器/热点。若用手机热点，注意流量。

---

## 11. 网络环境

| 环境 | 结果 | 说明 |
|---|---|---|
| 同一 5GHz Wi-Fi、未开隔离 | ✅ 最佳 | 当前环境 867 Mbps PHY、-51 dBm；2 Mbps 很小 |
| 2.4GHz | ⚠️ 可用但抖 | 自动降 720p15/10；不要期望 30fps |
| 公司 Wi-Fi 客户端隔离/访客网络 | ❌ 不可用 | 手机到 Mac 单播被拦；WebRTC 无法直连；BLE 传不了视频 |
| 手机 VPN | ⚠️ 可能不可用 | VPN 可能把局域网流量带走；需要分流 |
| macOS 防火墙/EDR | ⚠️ 可能被拦 | UDP 临时端口被拦；首次弹窗要允许 |
| Mac 睡眠/锁屏 | ❌ 无画面 | 捕获停止；唤醒后重连 |
| Mac 用有线 | ✅ 更稳 | 2014 款无内置网口，可用 Thunderbolt 转 Ethernet |
| 跨互联网 | ❌ 不在范围 | 不做中继；如确需，另立项目评估 Tailscale |

> **与 R-01 的关系**：公司网络若客户端隔离，语音还能靠 BLE 兜底，但**屏幕共享没有 BLE 兜底**。这是本功能的硬限制，UI 要明确说“需要同一局域网”。

---

## 12. 权限

### 12.1 macOS

| 项 | 说明 |
|---|---|
| 屏幕录制 TCC | 首次调用 `SCShareableContent` / `SCStream.startCapture` 时系统弹窗；用户到“系统设置 › 隐私与安全性 › 屏幕录制”手动勾选 |
| 重启 | 授权后通常需要重启 App；设置页显示“已授权，重启后生效” |
| 签名/路径绑定 | 与辅助功能相同：TCC 按 App 副本路径 + 代码签名记录；继续用 `/Applications/VoiceRelay.app` 和稳定证书 |
| MDM | 公司策略可能锁定/隐藏屏幕录制开关（Q-01）；不绕过，提示联系 IT |
| 系统指示 | 捕获期间 macOS 显示屏幕录制指示；不能隐藏 |
| 新系统复核 | macOS 14/15 之后提示更严格，存在周期性复核；升级后重新走授权 |
| 菜单栏 App | `LSUIElement` 首次弹窗可能不在前台；先激活 App 或显示引导窗口 |
| 开发重置 | `tccutil reset ScreenCapture com.voicerelay.app` 后重新勾选 |
| 辅助功能（跟随光标） | 用于读取 `AXFocusedUIElement` / `AXWindow`，复用 VoiceRelay 现有授权，不新增权限；未授权时退回前台 App 窗口，屏幕共享仍可用 |
| Secure Input | 焦点信息可能不可读；暂停跟随，保持当前窗口；按隐私规则暂停/模糊 |

**必需**：屏幕录制。  
**可选但推荐**：辅助功能（仅用于精确跟随光标；不授权也能共享，只是默认窗口退化为前台窗口）。  
**不需要**：输入监控、麦克风、完全磁盘访问。

### 12.2 iOS

| 项 | 说明 |
|---|---|
| 本地网络 | iOS 14+ 首次局域网访问弹窗；需要 `NSLocalNetworkUsageDescription`；Bonjour 需要 `NSBonjourServices` |
| 拒绝后果 | 发现和直连都可能失败；提供“去设置 › 隐私 › 本地网络” |
| 后台 | App 挂起，视频停止；V1 不做后台/PiP |
| 屏幕录制 | 手机端不需要；只有 Mac 需要 |
| 音频 | 不申请麦克风；不激活音频会话 |

### 12.3 Android

| 项 | 说明 |
|---|---|
| INTERNET | WebRTC 必需 |
| ACCESS_NETWORK_STATE | 判断 Wi-Fi/网络状态 |
| 屏幕录制 | 手机端不需要 |
| 前台服务 | V1 不需要；观看页前台运行，后台停止 |
| 明文流量 | 媒体走 UDP/DTLS，不涉及 HTTP 明文；若以后加 HTTP 缩略图，再配 `networkSecurityConfig` |

### 12.4 内容限制

- **DRM/受保护视频**：通常黑屏，无法绕过。
- **应用主动排除窗口**：`NSWindow.sharingType = .none` 的窗口可能缺失/黑块。
- **Secure Input**：保护键盘事件，不会自动给画面打码；检测到 Secure Input 时暂停或模糊整帧。
- **锁屏/登录窗**：不捕获；显示“Mac 已锁屏”。
- **通知/密码管理器**：整屏模式会包含；默认窗口模式降低暴露面。
- **多显示器**：窗口模式不依赖显示器；整屏模式需选择显示器。

---

## 13. 隐私与安全

### 13.1 产品规则

1. **默认关闭**，每次会话显式开始；不做“开机自动共享”。
2. **默认跟随文本光标窗口**，整屏需二次确认；整屏提示“可能包含密码、通知、聊天内容”。
3. **Mac 可见**：菜单栏共享标记 + 弹窗“正在共享：…”，一键停止。
4. **手机可见**：观看页绿点 + “只看不控”胶囊；没有伪装成普通页面的隐藏模式。
5. **自动停止**：手机切后台/锁屏立即停；Mac 锁屏/睡眠停；连续 30 分钟自动停。
6. **不落盘、不上云**：帧只在内存；日志只记字节数/fps/错误码，不记窗口标题、不记画面、不做 OCR。
7. **加密**：DTLS-SRTP；信令走已认证的 HMAC 会话；配对吊销 5 s 内终止会话。
8. **排除自身**：不捕获 VoiceRelay 的设置窗、二维码、配对码、权限页。
9. **敏感暂停**：Secure Input、密码管理器前台、DRM 窗口时暂停或模糊。
10. **无控制**：不实现 CGEvent、键盘、剪贴板、文件传输；降低被远程操纵的风险。
11. **缩略图最小化**：只在选择器打开时生成；只用于窗口选择；AES-GCM 加密分片传输；关闭即释放，不落盘、不日志、不做 OCR。

### 13.2 威胁模型

| 威胁 | 缓解 |
|---|---|
| 同局域网抓包 | DTLS-SRTP 加密；信令 HMAC；不传明文 SDP 以外内容 |
| 未配对设备发起共享 | 拒绝 `SCREEN_*`；必须已认证会话 |
| 手机丢失 | Mac 设置吊销配对；会话 5 s 内关闭 |
| 重放信令 | 现有计数器/会话 ID；`SCREEN_START` 带 nonce |
| 恶意窗口标题/内容 | 只显示文本，不执行；标题截断、转义 |
| 录屏/截图泄露 | 不落盘；手机端禁止系统截图？不做强限制，提示用户 |
| 缩略图抓包/泄露 | 仅发给已认证设备；AES-GCM 加密；分片重组后立即释放；不进日志 |
| 共享整屏泄露通知 | 默认窗口；整屏二次确认；可随时停止 |

### 13.3 文案

- 手机首次使用：“你将看到 Mac 上的真实画面，可能包含密码、聊天和通知。只在你自己的局域网内传输，随时可以停止。”
- Mac 弹窗：“正在共享：Safari — 项目文档”+“停止共享”。
- 整屏确认：“整个屏幕可能包含其他 App 的通知和密码框。确定共享整屏？”
- 权限拒绝：“没有屏幕录制权限，无法共享。去 Mac 的‘系统设置 › 隐私与安全性 › 屏幕录制’打开。”

---

## 14. 失败与降级

| 情况 | 手机表现 | 处理 |
|---|---|---|
| 屏幕录制未授权 | “需要在 Mac 上允许屏幕录制”+ 步骤 | 不建立 SCStream；Mac 设置页高亮权限卡 |
| 权限运行中撤销 | “屏幕录制权限已被关闭” | 停止流；保留语音；重新授权后可重试 |
| MDM 锁定 | “此权限由设备管理策略控制” | 不绕过；提示联系 IT |
| 没有可共享窗口 | 空态 + 刷新 | 不开始会话 |
| 跟随光标失败 | “无法读取光标，已使用前台窗口” | 不阻断；记录原因；可手动选择 |
| 辅助功能未授权 | “无法精确跟随光标”+ 去 Mac 设置 | 退回前台窗口；屏幕共享继续 |
| Secure Input | 保持当前窗口，画面可模糊/暂停 | 暂停跟随；恢复后重新解析 |
| 用户手动锁定 | 标题旁“已手动锁定” | 不自动切换；显式恢复跟随才解除 |
| 窗口关闭 | “窗口已关闭”+ 重新选择 | 停止流；保留最后一帧 |
| 窗口最小化 | “窗口已最小化” | 暂停；恢复后重试 |
| Mac 锁屏/睡眠 | “Mac 已锁屏/睡眠” | 停止流；唤醒后重连一次 |
| Wi-Fi 断开/AP 隔离 | “不在同一局域网或连接中断” | 重连 3 次；失败结束 |
| UDP 被防火墙拦 | “网络被拦截” | 提示检查防火墙/EDR；V1 不做 TURN |
| H.264 协商失败 | “已切换兼容模式” | 回退 VP8；提示可能发热 |
| 编码失败 | “编码器不可用” | 回退软件；仍失败则停止 |
| 手机切后台/锁屏 | 停止 | 释放 renderer；回前台重新开始 |
| iOS 本地网络被拒 | “需要本地网络权限” | 去设置；不能自动发现 |
| 手机过热/低电量 | 降 15fps 或提示 | 不静默卡死 |

---

## 15. 实施计划

| 阶段 | 内容 | 产出 | 预估 |
|---|---|---|---|
| **S6a** | SCK 权限、窗口列表、FocusTracker 焦点窗口解析、单窗口捕获、1280×800 单帧 | 能稳定拿到焦点窗口帧；确认 TCC/老 GPU | 1–2 天 |
| **S6b** | WebRTC 测试画面 Mac → Android | 确认 P2P、mDNS、防火墙、H.264 硬解、延迟 | 1–2 天 |
| **S6c** | SCK → WebRTC 720p30 窗口流 | 端到端画面；记录 CPU/延迟/丢帧 | 2–3 天 |
| **M1** | Android 观看页、窗口选择、跟随/锁定、切换、状态、统计 | Android 可用版 | 3–5 天 |
| **M2** | iOS 工程生成、权限、观看页、真机验证 | iOS 可用版 | 3–5 天 |
| **M3** | 隐私、自动停止、异常矩阵、性能调优、测试 | 可交付版 | 2–3 天 |
| **合计** | Android 优先 + iOS 同步 | 约 **2–3 周**，含缓冲 3–4 周 | |

**顺序原则**：先 Android 打通，再 iOS 复用；不要为 Android 和 iOS 各写一套协议/状态机。窗口切换、自动停止、权限引导在 M1/M2 都要实现，不留给“以后”。

---

## 16. 验收

### 16.1 功能

- 手机能列出 Mac 当前可共享窗口；默认跟随文本光标所在窗口，失败退回前台窗口。
- 跟随：Safari 地址栏、Chrome 输入框、VSCode 编辑器、飞书/微信输入框中识别正确；Cmd+Tab 后 500 ms 内跟随。
- 手动选择窗口后锁定，不自动抢回；重新打开“跟随输入光标”可恢复。
- 720p30 连续观看 30 分钟；窗口切换 < 1.5 s；首帧 < 2 s。
- 暂停/继续/停止/切换窗口都可用；手机横屏、缩放、双击 1:1 可用。
- 整屏入口可用，但必须二次确认；默认仍为窗口。
- 选择器首屏缩略图 500 ms 内出现；无缩略图/受保护窗口显示 App 图标；缩略图不阻塞列表。
- Mac 菜单栏有共享指示，可一键停止；手机切后台立即停。
- 无声音、无控制、无剪贴板；UI 有“只看不控”标识。

### 16.2 性能

| 指标 | 通过标准 |
|---|---|
| 分辨率/帧率 | 1280×800 · 30fps（网络差时自动降 15/10） |
| 丢帧 | 30 分钟 < 2% |
| 延迟 | 玻璃到玻璃 P95 < 300 ms |
| Mac CPU | 共享空闲增量 < 20%；与 ASR 并发 < 40% |
| Mac 内存 | 30 分钟增长 < 100 MB |
| 缩略图 | 12 个窗口生成 < 300 ms；内存峰值 < 20 MB；关闭选择器后释放 |
| Android 耗电 | 30 分钟 < 10%（目标机型） |
| iPhone 耗电 | 30 分钟 < 12% |
| 热 | 30 分钟不出现明显降频/风扇狂转 |

### 16.3 网络/权限/隐私矩阵

| 类别 | 用例 |
|---|---|
| 网络 | 5GHz / 2.4GHz / AP 隔离 / 访客 VLAN / 手机 VPN / macOS 防火墙 / Mac 睡眠唤醒 / Wi-Fi 漫游 |
| 权限 | 首次拒绝 / 授权 / 运行中撤销 / 重装 / 换签名 / MDM / 系统升级 |
| 窗口 | 前台/后台/被遮挡/最小化/关闭/跨显示器/不同宽高比/全屏 App |
| 焦点 | Safari 地址栏 / Chrome 输入框 / VSCode / 飞书 / 微信 / Finder / Electron / Java / sheet / popover / Cmd+Tab / Secure Input / AX 拒绝 |
| 缩略图 | 普通窗口 / 最小化 / 被遮挡 / DRM / 受保护 / 多窗口 / 无缩略图回退 / 选择器快速开关 |
| 内容 | 普通文档 / 代码 / 视频 / DRM / 密码框 / 通知 / 锁屏 |
| 设备 | Android 10+ 目标机（Q-02）/ iPhone iOS 15+（Q-03）/ Android 低端机 H.264 兜底 |
| 并发 | 共享时按住说话 / 切 App / 注入文本 / 蓝牙连接 |
| 安全 | 未配对设备 / 重放 / 吊销后重连 / 抓包 / 日志检查 |

---

## 17. 风险

| 编号 | 风险 | 影响 | 缓解 |
|---|---|---|---|
| R-15 | 屏幕内容泄露（密码、通知、聊天） | 高 | 默认窗口、整屏二次确认、自动停止、不落盘、Secure Input 暂停 |
| R-16 | 屏幕录制 TCC 被 MDM 锁定 | 功能不可用 | 先确认 Q-01；UI 明确说明；不绕过 |
| R-17 | 公司 Wi-Fi 客户端隔离 | 公司场景不可用 | 明确“仅同一局域网”；不承诺 BLE 视频 |
| R-18 | 2014 Intel GPU 采集/缩放不稳 | 掉帧、发热 | 720p、queueDepth 3、丢旧帧；S6 压测；必要时降低帧率 |
| R-19 | WebRTC.xcframework 接入/签名复杂 | 构建失败、工期延长 | S6b 先做最小 P2P；binaryTarget 固定版本；保留 TCP 兜底方案 |
| R-20 | iOS 工程未生成 / Xcode 版本不足 | iOS 延期 | M2 先 `flutter create`；确认 Q-03；必要时升级 macOS/Xcode |
| R-21 | 窗口捕获光标不显示/遮挡窗口异常 | 体验差 | S6a 验证；必要时整屏或额外光标层 |
| R-22 | Android 机型 H.264 解码差异 | 黑屏/花屏 | H.264 优先、VP8 兜底；目标机实测 |
| R-23 | SDP 超过控制帧上限 | 信令失败 | 分片或提高上限；S6b 验证 |
| R-24 | UDP 被防火墙/EDR 拦 | 无法连接 | 首次弹窗允许；错误提示；V1 不做 TURN |
| R-25 | AX 焦点信息不完整/匹配错窗口 | 共享错窗口 | PID + 标题 + 矩形匹配；手动覆盖；失败回退前台；S6 覆盖 Electron/Java |
| R-26 | 自动跟随频繁切换/打断 | 体验差 | 300–500 ms 防抖；菜单/popover 不跟；手动选择后锁定 |
| R-27 | Android 10+/iOS 15+ 版本门槛 | 老设备不支持 | 明确基线；Android `minSdk = 29`；iOS deployment target 15.0；启动时提示 |
| R-28 | 缩略图捕获卡顿/泄露窗口内容 | 选择器变慢、隐私风险 | 只截前 12 个、并发 2、后台队列；AES-GCM 分片；关闭即释放；失败回退 App 图标 |

---

## 18. 对现有文档/决策的影响

| 文档 | 需要改什么 |
|---|---|
| `docs/01-architecture.md` | 新增 `ScreenSession` / `WindowCatalog` / `FocusTracker` / `ScreenSignal` 模块；补数据流 |
| `docs/02-protocol.md` | 新增 `CMD 0x0F SCREEN`、窗口列表、`thumb_*` 分片、`follow` 开关、SDP/ICE 信令、SDP 分片 |
| `docs/03-ui-mobile.md` | 新增共享入口、窗口选择器（含缩略图/跟随开关）、横屏观看页、状态表 |
| `docs/04-ui-mac.md` | 设置新增“屏幕共享”分区（含跟随光标）；菜单栏共享态；权限卡 |
| `docs/05-permissions-onboarding.md` | 当前写“不需要屏幕录制”；新增第四张权限卡；辅助功能说明补充“也用于精确跟随屏幕窗口”，未授权时降级 |
| `docs/07-validation-plan.md` | 新增 S6（S6a/S6b/S6c）与终止条件，含焦点跟随用例 |
| `docs/08-risks.md` | 新增 R-15…R-28 |
| `docs/09-decisions.md` | 建议新增 D-13…D-18（见下） |
| `README.md` | 功能状态、权限说明、版本基线、已知限制、文档索引 |

### 建议新增决策

| 编号 | 决策 |
|---|---|
| D-13 | 屏幕共享为“只看不控”，仅局域网，720p30，无系统声音 |
| D-14 | 默认跟随文本光标所在窗口；手动选择后暂停跟随；整屏保留并需二次确认 |
| D-15 | 媒体走 WebRTC H.264，信令走 8787；视频不走 BLE，不做互联网中继 |
| D-16 | 屏幕录制必需；辅助功能仅用于精确跟随，未授权时退回前台窗口；权限拒绝不影响语音 |
| D-17 | 版本基线：iOS 15+、Android 10+（API 29）；整屏模式保留 |
| D-18 | 窗口选择器显示缩略图；缩略图仅在选择器打开时生成，AES-GCM 分片传输，关闭即释放 |

---

## 19. 待确认

1. **自动停止时长**：30 分钟是否合适？还是 10 分钟 / 从不？
2. **跟随策略**：默认“连续跟随”（焦点变化自动切换），手动选择后锁定；是否接受？
3. **缩略图清晰度**：72×45 显示、320×200 源图是否够？需要更大可改 480×300。
4. **Android 目标机**：Q-02 的型号/系统版本，决定 H.264 硬解与耗电测试基线。
5. **iOS 版本/Xcode**：Q-03 是否升级；当前工程没有 `ios/` 目录，需要生成。
6. **命名**：手机端叫“共享屏幕”还是“查看屏幕”？本文暂用“共享屏幕”。

---

## 20. 附录：S6 验证清单

### S6a · 采集与权限

- [ ] 首次调用 SCK 能弹出屏幕录制授权；拒绝后不崩溃。
- [ ] 授权后重启 App，能列出窗口。
- [ ] 能对单个窗口输出 1280×800 帧；窗口被遮挡仍可捕获。
- [ ] 窗口最小化/关闭时能收到停止或错误。
- [ ] 1280×800 下 CPU/GPU 占用可接受。
- [ ] FocusTracker 能在 Safari 地址栏、Chrome 输入框、VSCode 编辑器、飞书/微信输入框中定位到正确窗口。
- [ ] Cmd+Tab、sheet、popover 不会误跟随；手动选择后不自动抢回。
- [ ] 辅助功能拒绝/Secure Input 时能退回前台窗口，共享不中断。
- [ ] 缩略图：12 个窗口 < 300 ms；加密分片能重组；选择器关闭后内存释放。
- [ ] 最小化/DRM/受保护窗口回退 App 图标，不显示破图。

### S6b · WebRTC 最小链路

- [ ] Mac 发送测试画面，Android 能收到 720p30。
- [ ] 确认 H.264 硬编/硬解，不是软编。
- [ ] 记录首帧、P95 延迟、丢帧、码率。
- [ ] 确认 mDNS/防火墙/UDP 端口行为。
- [ ] iOS 同样跑通一次（如果工程已生成）。

### S6c · 真实窗口流

- [ ] SCK → WebRTC 720p30 稳定 10 分钟。
- [ ] 窗口切换 < 1.5 s，旧帧保留。
- [ ] 连续跟随：焦点变化 300–500 ms 内切换，不闪、不误切菜单/浮层。
- [ ] 手动锁定/恢复跟随都生效；整屏入口二次确认生效。
- [ ] 共享时按住说话，语音 P95 不明显退化。
- [ ] Mac 锁屏/唤醒、Wi-Fi 断开/恢复行为正确。

### 终止条件

- S6b 无法在 3 天内跑通 P2P，或延迟 P95 > 500 ms：暂停 WebRTC 方案，评估 TCP H.264/JPEG 兜底。
- S6c 720p30 连续 10 分钟丢帧 > 10%，或 Mac CPU > 50%：降 720p15 或 960×600，再评估。
- 关键 App（Safari/Chrome/VSCode/飞书/微信）焦点窗口识别失败率 > 20%：默认改为前台窗口 + 手动选择，保留“跟随”作为实验开关。
- 屏幕录制权限被 MDM 锁定且无法申请：功能仅限个人设备，公司场景明确不支持。
