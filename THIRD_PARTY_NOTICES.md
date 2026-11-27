# 第三方组件与许可证

VoiceRelay 的**源代码**以 [MIT](LICENSE) 发布。下列第三方组件、二进制与模型权重遵循各自许可证；本项目不重新授权它们。

## 随源代码/安装包分发

| 组件 | 用途 | 许可证 | 链接 |
|---|---|---|---|
| sherpa-onnx 2.0.3 | 本地语音识别运行时 | Apache-2.0 | <https://github.com/k2-fsa/sherpa-onnx> |
| ONNX Runtime | 推理后端（随 sherpa-onnx 分发） | MIT | <https://github.com/microsoft/onnxruntime> |
| WebRTC.framework (x86_64) | 屏幕共享推流/收流（Intel 构建） | BSD-3-Clause | <https://webrtc.org/> |
| LiveKitWebRTC.xcframework (arm64) | 屏幕共享推流/收流（Apple Silicon 构建） | BSD-3-Clause | <https://github.com/livekit/webrtc-xcframework> |
| Opus | 音频编码（协议预留） | BSD-3-Clause | <https://opus-codec.org/> |
| Flutter / Dart | 手机端框架 | BSD-3-Clause | <https://flutter.dev> |

WebRTC.xcframework、LiveKitWebRTC.xcframework（仅 macOS arm64 切片）与 Opus 静态库为预编译二进制，位于 `mac/vendor/`；sherpa-onnx 运行时由 `mac/scripts/fetch-deps.sh` 在构建时下载，不进入仓库。二进制中的版权声明归其作者所有。

## 手机端 Dart 依赖

`mobile/voicerelay/pubspec.yaml` 直接依赖：`crypto`、`record`、`permission_handler`、`shared_preferences`、`flutter_blue_plus`、`multicast_dns`、`mobile_scanner`、`flutter_webrtc`，以及 Flutter SDK 自带的包。

这些包的许可证随包发布，完整清单与版本见 `pubspec.lock`；发布二进制前请在你的 `LICENSES` 页面或关于页保留其版权声明。各包许可证可在 <https://pub.dev> 对应包页面查看。

## 模型权重（不随安装包分发）

**SenseVoice Small int8** 由 [sherpa-onnx 官方 Release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models) 提供，原始模型来自 [FunAudioLLM/SenseVoice](https://github.com/FunAudioLLM/SenseVoice)，经 FunASR 导出。

- 代码（FunASR 工具链）为 MIT；**预训练模型权重单独授权**，以其模型卡/许可协议为准。
- 本项目**不打包、不再分发**模型权重：App 首次运行时由用户从上述官方地址下载到本机。
- 模型目录中的 `LICENSE` 文件指向 <https://github.com/modelscope/FunASR?tab=readme-ov-file#license>。商用或再分发前请自行确认条款。

## 可选、未打包的组件

| 组件 | 说明 | 许可证 |
|---|---|---|
| BlackHole（或同类虚拟声卡） | 后端 B 需要用户自行安装虚拟音频设备，本项目不包含其二进制 | GPL-3.0 |

后端 B 默认关闭，仅在你自行安装虚拟声卡并主动切换时使用。

## 字体与图标

应用图标由本项目 [`tools/icons/`](tools/icons) 中的矢量母版生成；如使用了第三方字体或图标素材，请在该目录补充来源与许可证。
