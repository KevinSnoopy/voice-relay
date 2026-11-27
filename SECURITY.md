# 安全策略

## 支持范围

只有最新 Release 会收到安全修复。当前为 `1.0.x`。

## 私下报告漏洞

请**不要**开公开 Issue。使用 GitHub 的私密漏洞报告：

<https://github.com/KevinSnoopy/voice-relay/security/advisories/new>

请在报告里尽量包含：

- 受影响版本与平台（macOS / Android / iOS）
- 复现步骤或最小 PoC
- 影响描述（能读到什么、能写到哪里、是否需要同一局域网）
- 你希望的署名方式

一般 3 个工作日内回复。修复发布后会在 Release Notes 与 Security Advisory 中致谢（除非你要求匿名）。

## 威胁模型

VoiceRelay 假设：手机和 Mac 在同一个**可信局域网**内；使用者的 Mac 已经授予辅助功能权限；攻击者不在同一网络，或即使在同一网络也不能被动嗅探 Wi-Fi（推荐 WPA2/3）。

设计上做了这些防护：

- **配对**：6 位一次性确认码 + 双方随机数，HKDF 派生 32 字节长期密钥；确认码不用于后续通信。
- **密钥存储**：macOS 钥匙串 / iOS Keychain / Android Keystore；不写入明文配置。
- **帧认证**：每个音频/控制帧带 HMAC，防篡改与重放（序号单调递增）。
- **模型下载**：仅从 `github.com/k2-fsa/sherpa-onnx` 的 HTTPS Release 下载，解压后校验 `model.int8.onnx` 与 `tokens.txt` 存在。
- **无遥测**：不上传音频、识别文本、设备信息；没有账号和后端服务。
- **Secure Input**：检测到密码框时直接拒绝注入。

## 不属于漏洞的情况

- 需要先在本机获得代码执行/管理员权限的攻击。
- 未公证导致的首启 Gatekeeper 提示（这是分发限制，不是漏洞）。
- 同一用户会话内，其他有辅助功能权限的 App 能读到你屏幕上的文字。
- 用户自己把配对码/二维码给别人。
- 已知未验收功能（BLE、屏幕观看）在特定硬件上的崩溃——请按普通 Bug 报告，附机型与日志。

## 加固建议

- 只在信任的 Wi-Fi 使用；公共网络建议开启 BLE 备用通道或不用。
- 不用时退出 App，或在设置里关闭监听。
- 定期在 Mac 设置里吊销不用的已配对设备。
- 不要把 `~/Library/Application Support/VoiceRelay/` 和手机备份随意分享。
