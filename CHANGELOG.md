# Changelog

本项目从 v1.0.0 开始对外开源。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循语义化版本。

## [1.0.0] - 2026-11-27

首个开源版本。

### Added

- macOS 菜单栏 App：配对二维码、权限检查、连接状态、最近上屏记录、设备吊销。
- Mac 端本机识别：sherpa-onnx 2.0.3 + SenseVoice Small int8，中文逐字正确，5.3 s 音频推理约 280–310 ms。
- 首次运行在 App 内下载语音模型（约 155 MB），不再需要手动跑脚本。
- 文字注入三级路径：Accessibility → Unicode → 粘贴（默认关闭自动粘贴），以回读结果判定成功。
- 系统级 App / 窗口切换、上一个/下一个输入框、回车、退格、全选、撤销等控制键。
- 手机端 Flutter App：按住说话、TCP 传输、Bonjour 自动发现、二维码扫描、BLE 扫描与连接。
- 屏幕共享（只看不控）：窗口目录、焦点跟随、缩略图、ScreenCaptureKit 采集、WebRTC 信令与视频轨道。
- 打包脚本：`mac/scripts/package-dmg.sh`、`mobile/scripts/build-apk.sh`。
- macOS DMG 与 Android APK 安装包。

### Known limitations

- macOS 安装包为 x86_64，Apple Silicon 需 Rosetta；原生 arm64 构建待贡献。
- 未做 Apple 公证；首次打开需手动放行。
- BLE、Android 真机、iOS 真机、屏幕视频播放尚未完成硬件验收。
- 后端 B（虚拟声卡 + 第三方输入法）未做虚拟声卡验收。
