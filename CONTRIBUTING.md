# 参与贡献

谢谢你愿意一起把 VoiceRelay 做好。这个项目还在早期，任何形式的帮助都算数：报 Bug、补文档、翻译、验证硬件、改代码。

## 先聊一下

- 小的修复（错别字、文档、明显的 Bug）直接开 PR。
- 新功能、协议变更、UI 大改，先开 Issue 描述场景和方案，避免白做。
- 安全问题不要开公开 Issue，见 [SECURITY.md](SECURITY.md)。

## 开发环境

| 部分 | 需要 |
|---|---|
| macOS App | macOS 13+、Xcode 15+（Swift 5.9） |
| 手机 App | Flutter 3.38.x、Android SDK、JDK 17；iOS 需要 Xcode + 自己的 Team |
| 原型 | Node.js 18+（仅评审用，不参与产品构建） |

```bash
git clone https://github.com/KevinSnoopy/voice-relay.git
cd voice-relay

# macOS
cd mac
./scripts/fetch-deps.sh     # 下载预编译 sherpa-onnx（不提交进仓库）
swift build
swift test                  # 15 个协议/认证/PCM 测试

# Flutter
cd ../mobile/voicerelay
flutter pub get
flutter analyze
flutter test
```

`ios/`、`android/` 平台目录已提交，不需要再执行 `flutter create`。如果 Flutter 升级后提示平台工程过旧，请单独开 PR 更新，不要整目录重新生成后混入无关改动。

## 代码约定

- Swift：跟随现有结构，`VoiceRelayCore` 保持无 UI 依赖、可单测；新增逻辑优先写测试。
- Dart：`flutter analyze` 必须零警告；协议改动必须同步 `test/protocol/`。
- 协议：任何帧格式、端口、认证变更都要同时改 [`docs/02-protocol.md`](docs/02-protocol.md) 和两端实现。
- 文档：中文为主，术语保留英文原名（如 Accessibility、Bonjour、WebRTC）。
- 提交信息用祈使句，建议 `feat:` / `fix:` / `docs:` / `test:` / `chore:` 前缀。
- 不要提交 `mac/vendor/sherpa-onnx-*`、模型权重、`build/`、`node_modules/`、keystore、`local.properties` 或个人路径。

## 改动检查清单

提交 PR 前请确认：

- [ ] `cd mac && swift test` 通过（改了 Mac 代码时）。
- [ ] `cd mobile/voicerelay && flutter analyze && flutter test` 通过（改了手机端时）。
- [ ] 新增/修改的行为有对应文档或测试。
- [ ] 没有把演示数据（原型）当成真实运行结果写进文档。
- [ ] UI 改动附截图或录屏；硬件相关改动注明机型、系统版本、验证步骤。
- [ ] 没有提交密钥、证书、个人路径、模型文件。

## 特别需要帮忙的方向

1. **universal DMG**：目前 `arm64` 与 `x86_64` 分开出包，可以研究合成 universal 包（WebRTC 需要一份同时含两种架构的构建）。
2. **iOS 真机**：权限、后台、WebRTC 播放。
3. **BLE 验收**：不同 Android 厂商的后台与 GATT MTU 差异。
4. **屏幕观看**：真机视频首帧、延迟、横屏体验。
5. **Windows / Linux 端**：`VoiceRelayCore` 的协议与注入逻辑可以参考，UI 需要新写。
6. 文档英译、安装引导文案、错误提示。

## 发布

打包、签名、发布流程见 [`docs/RELEASING.md`](docs/RELEASING.md)。维护者会在合并影响用户的改动后更新 [CHANGELOG.md](CHANGELOG.md)。

## 行为准则

参与本项目即表示同意遵守 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。
