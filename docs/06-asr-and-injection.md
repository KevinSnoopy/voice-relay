# 06 · 识别与注入


> 模型已定：sherpa-onnx v2.0.3 + SenseVoice Small（int8），见 D-02。原型 `D-07` 已同步为 `SenseVoice Small（int8）`（2026-11-26）。

## 1. 识别引擎

### 选型

| 方案 | 形态 | 中文 | 标点 | Intel CPU | 结论 |
|---|---|---|---|---|---|
| **SenseVoice-small（int8）** | 整段 | 好，自带 ITN | ✅ 自带 | 快 | **V1 默认** |
| streaming-zipformer bilingual（int8） | 流式 | 中上 | ❌ 需外挂 | 中 | V2 候选 |
| streaming-paraformer bilingual | 流式 | 中上 | ❌ 需外挂 | 中 | 备选 |

V1 选整段识别的理由：按住说话本来就是"松手出字"，整段模型自带标点与数字规范化，少一个模型、少一层调参。若实测端到端超过 1 秒再换流式。

### 运行参数

| 参数 | 值 | 说明 |
|---|---|---|
| 采样率 | 16 kHz，单声道，float32 | 手机侧统一转换后再编码 |
| 解码 | greedy search | 首版够用 |
| 线程数 | 4（按 CPU 核心数上限 6） | Intel 四核机器取 4 |
| `use_itn` | true | 数字、时间、金额规范化 |
| 语言 | zh（可切 auto） | 中英混说用 auto |
| 最长单段 | 60 s | 超过自动切段 |
| VAD | silero-vad，可选 | 用来裁掉首尾静音，降低 RTF |

### 集成方式

- 用官方 `sherpa-onnx-v2.0.3-osx-x64-static` 预编译库，C API + Swift bridging header。
- 模型文件放 `~/Library/Application Support/VoiceRelay/models/`，首次启动解压，不打包进 `.app`（体积太大）。
- App 启动后在后台线程加载模型，加载完成前菜单栏图标显示"模型加载中"，语音按钮禁用。
- 加载失败 → 状态行报错 + 「重新加载模型」按钮，不崩溃。

### 延迟预算（目标 P95 < 1000 ms）

| 环节 | 预算 |
|---|---|
| 手机采集 + Opus 编码（40 ms 包） | 60 ms |
| Wi-Fi 单程 | 10–40 ms |
| 解码 + 重采样 | 15 ms |
| 识别推理（8 s 音频） | 300–600 ms |
| 注入（AX / 粘贴） | 10–150 ms |
| **合计** | **400–900 ms** |

超过 1200 ms 要记录一条 `slow` 日志，包含各段耗时。

## 2. 文本注入

### 决策树

```
拿到最终文本
  │
  ├─ 前台 App 是 Secure Input？ ── 是 → 放弃，回 ERROR(0x31)，文本进剪贴板
  │
  ├─ AX 焦点元素是可编辑文本？（role ∈ {AXTextField, AXTextArea, AXComboBox}）
  │     ├─ 是 → ① AX 写入  ── 成功 → 完成
  │     └─ 否 → 找当前窗口内第一个可编辑元素，尝试聚焦后写入
  │
  ├─ ② Unicode 键盘事件（CGEventKeyboardSetUnicodeString）
  │     └─ 成功且回读一致 → 完成
  │
  └─ ③ 剪贴板 + ⌘V
        └─ 保存原剪贴板 → 写入 → postToPid(⌘V) → 300 ms 后恢复
```

### 三级方案细节

| 级别 | 做法 | 优点 | 缺点 | 适用 |
|---|---|---|---|---|
| ① AX 写入 | `AXUIElementSetAttributeValue(el, kAXValueAttribute, text)` | 干净、不碰剪贴板、可回读校验 | Electron/网页常失败；部分 App 需要发 `AXConfirm` | 原生 App：备忘录、Pages、Xcode |
| ② Unicode 事件 | 文本切成 ≤ 20 字符的块，`CGEvent` + `postToPid` | 兼容 Chromium 系 | 走输入法管道的 App 会丢字；长文本慢 | Chrome、VSCode、Slack |
| ③ 粘贴 | `NSPasteboard` + `⌘V` | 兼容性最好 | 污染剪贴板；目标不支持粘贴则失败 | 飞书、微信、其他兜底 |

硬规则：

- ①失败才降级到②，②失败才降级到③，不允许跳级。
- ③ 必须保存并恢复剪贴板**全部类型**（`NSPasteboardItem` 逐个保存），恢复失败要写日志。
- 所有注入都用 `CGEvent.postToPid(frontmostPID)`，不要用全局 `post`，避免投到别的窗口。
- 注入前记录前台 App 的 bundleId，注入后再确认一次，防止中途切换。

### 已知的坑

| 现象 | 原因 | 处理 |
|---|---|---|
| 长中文只进去前几个字 | ② 走输入法管道被吞 | 超过 12 字直接走③ |
| 文本进去了但光标位置错 | 目标 App 异步处理 | 注入后等 120 ms 再回读 `kAXValueAttribute` 校验 |
| 粘贴后剪贴板没恢复 | 目标 App 延迟读取剪贴板 | 恢复延迟从 300 ms 提到 800 ms，并做二次校验 |
| 密码框被写入 | Secure Input 判定漏了 | 每次注入前查 `IsSecureEventInputEnabled()` |
| 焦点在地址栏却写进网页 | AX 层级与实际焦点不一致 | 以 `kAXFocusedUIElement` 为准，不猜 |

### Secure Input

- 用 `IsSecureEventInputEnabled()` 判断，返回 true 就拒绝注入并回 `0x31`。
- 终端（Terminal/iTerm）、密码框、系统登录窗都会触发。
- 不尝试绕过，这是安全边界。

## 3. 切换 App 与输入框

### 切 App

```
CMD(0x0B / 0x0C)
  → 遍历所有 regular App，按最近启动顺序选择目标
  → unhide + activate；仍未置顶时使用 open -b 强制恢复
  → 轮询确认目标 App 已成为前台进程
  → 回 CMD_ACK + STATE
```

- 不再发送合成 ⌘Tab，避免系统 App 切换条残留。
- 不维护 App 白名单，覆盖所有正在运行的 App。
- 手机端对 App/窗口切换显示 2 秒自动消失的轻量确认，不阻塞继续操作。

### 激活光标

```
CMD(0x0E)
  → unhide + activate 当前 App，必要时 open -b 强制置顶
  → 优先聚焦 kAXFocusedUIElement（文本角色即可，不要求 value 可写）
  → 否则查找 AXTextField / AXTextArea / AXComboBox / AXSearchField
  → 最后尝试聚焦当前可聚焦 AX 元素
  → 回 CMD_ACK + STATE
```

### 切输入框

```
CMD(0x02 / 0x03)
  → 取 kAXFocusedUIElement
  → 向上找容器（AXGroup / AXWindow）
  → 按 AXChildren 深度优先，找下一个 role ∈ {AXTextField, AXTextArea, AXComboBox}
  → 设 kAXFocusedAttribute = true
  → 失败 → 回退发送 Tab（或 Shift+Tab）
  → 都没有 → 回 CMD_ACK(fail)
```

已知无效场景（要在 UI 上提示，不要静默失败）：

- 游戏、远程桌面、部分 Java 应用：没有可用的无障碍树。
- Electron：部分版本无障碍树不完整，Tab 往往有效。
- 浏览器网页内部：Tab 走 DOM 焦点，能跳输入框，但不一定是"视觉上的下一个"。

## 4. 日志与诊断

必须记录（本地文件，保留 3 天）：

| 字段 | 说明 |
|---|---|
| `session_id` | 一次收音的 ID |
| `audio_ms` / `asr_ms` / `inject_ms` | 分段耗时 |
| `inject_path` | `ax` / `unicode` / `paste` |
| `front_app` | bundleId |
| `result` | `ok` / `no_field` / `secure` / `unsupported` |
| `text_len` | 只记录长度，**不记录文本内容** |

不记录：音频、识别文本、剪贴板内容、蓝牙地址。
