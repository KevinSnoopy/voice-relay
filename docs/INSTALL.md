# 安装与首次运行

## macOS

### 1. 安装

1. 从 [Releases](https://github.com/KevinSnoopy/voice-relay/releases/latest) 下载 `VoiceRelay-1.0.0.dmg`。
2. 双击打开，把 **VoiceRelay.app** 拖进 **Applications**。
3. 首次打开：在 Finder 里**右键 → 打开 → 打开**。
   如果仍被拦截，到 **系统设置 › 隐私与安全性**，在底部点 **仍要打开**。

> DMG 是 ad-hoc 签名、未公证的社区构建，所以系统会要求手动确认一次。校验完整性：
>
> ```bash
> shasum -a 256 VoiceRelay-1.0.0.dmg
> ```

### 2. 授权

VoiceRelay 是菜单栏 App，启动后没有 Dock 图标，请到屏幕右上角菜单栏找麦克风/圆点图标。

- **辅助功能**（必须）：用于把识别出的文字写进当前输入框。
  系统设置 › 隐私与安全性 › 辅助功能 → 勾选 VoiceRelay。
- **麦克风 / 屏幕录制 / 蓝牙**：按需授予；只有用屏幕共享或 BLE 时才需要。
- 如果授权后仍显示未授权，退出 App 再打开；换过安装位置或签名后执行一次：

  ```bash
  tccutil reset Accessibility com.voicerelay.app
  ```

  然后重新勾选并重启 App。

### 3. 下载语音模型

首次打开向导第一步会显示「语音模型未安装」，点 **下载（约 155 MB）**。
也可以到 **设置 › 语音 › 模型** 里点「下载语音模型」。

- 模型来自 sherpa-onnx 官方 Release，解压到 `~/Library/Application Support/VoiceRelay/models/`。
- 下载完成后会自动加载，状态变为 `SenseVoice Small (int8)`。
- 网络受限时，也可以在源码目录执行 `mac/scripts/download-models.sh`。

### 4. 连接手机

1. 手机和 Mac 连同一个 Wi-Fi（不要用访客网络/开了客户端隔离的网络）。
2. 手机打开 VoiceRelay，点「连接 Mac」，扫描 Mac 弹窗里的二维码。
3. 或手动填 `Mac 的 IP:8787` 和 6 位配对码。
4. 首次连接会确认一次，之后长期密钥自动重连。

### 5. 说话

在手机主屏按住按钮说话，松手。文字会出现在 Mac **当前光标**处。
如果注入失败，文字会留在手机结果卡里，可手动复制，不会假报成功。

### 常见问题

| 现象 | 处理 |
|---|---|
| 菜单栏没有图标 | 确认 App 在运行；`open /Applications/VoiceRelay.app`；LSUIElement 应用不显示 Dock 图标 |
| 手机找不到 Mac | 同一 Wi-Fi？关闭 AP 隔离/访客网络；macOS 防火墙放行 VoiceRelay；手动填 IP 试 |
| 能连上但没反应 | 检查辅助功能权限；看 App 设置里的「最近错误」；重启 App |
| 识别很慢 | Apple Silicon 上经 Rosetta 运行会慢；Intel 上确认没有其他大任务占 CPU |
| 提示模型缺失 | 设置 › 模型 › 下载语音模型；或 `mac/scripts/download-models.sh` |
| 屏幕共享黑屏 | 授予「屏幕录制」权限后**重启 App**；仅支持 macOS 13+ |

## Android

1. 下载 `VoiceRelay-1.0.0.apk`。
2. 允许「安装未知来源应用」，安装。
3. 首次打开授予麦克风、相机（扫码）、附近设备（BLE）权限。
4. 连接步骤同上。

> APK 使用 debug 签名，适合侧载体验；Play Protect 可能提示「未知开发者」，选择继续安装即可。长期分发请自行配置 release keystore，见 [RELEASING.md](RELEASING.md)。

## iOS

暂无预编译 IPA。用 Xcode 构建：

```bash
cd mobile/voicerelay
flutter pub get
open ios/Runner.xcworkspace
```

在 Runner target 里选择自己的 Team，连接真机运行。iOS 无法侧载未签名 IPA，这是平台限制。
