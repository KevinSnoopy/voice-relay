# VoiceRelay 手机端（Flutter）

手机只做三件事：采集 16 kHz 单声道音频、发按键、显示状态。识别与注入都在 Mac 端完成。

## 功能

- 自定义二进制帧、HMAC 认证（与 `mac/Sources/VoiceRelayCore/Wire.swift` 一致）
- **TCP**（端口 8787）与 **BLE GATT** 两条传输，统一 `RelayTransport` 抽象
- 手填 IP/配对码、**Bonjour 自动发现**、**二维码扫描**、**BLE 扫描**
- 按住说话：PCM16 / 16 kHz / 40 ms 一帧，松手发 `STREAM_STOP`
- 收 `LEVEL`、`RESULT`、`STATE`，展示最近一条、延迟、失败原因
- 控制面板：切 App、上一个/下一个输入框、回车、退格、全选、撤销、复制最近
- 屏幕观看：窗口选择、缩略图、WebRTC 视频（只看不控）

## 构建

需要 Flutter 3.38.x（见 `.fvmrc`）、Android SDK、JDK 17。

```bash
flutter pub get
flutter analyze
flutter test

# 通用 APK（含 debug 签名，可侧载）
flutter build apk --release
# 或使用根仓库脚本
../scripts/build-apk.sh
```

`android/` 与 `ios/` 平台目录已提交，**不需要**再执行 `flutter create`。

### iOS

```bash
flutter pub get
open ios/Runner.xcworkspace
```

在 Runner target 选择自己的 Team 后真机运行。所需权限文案已在 `ios/Runner/Info.plist` 声明：麦克风、相机、蓝牙、本地网络、Bonjour。

### Android 权限

已写入 `android/app/src/main/AndroidManifest.xml`：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
    android:maxSdkVersion="30"/>
```

`minSdk = 29`（Android 10）。

## 与 Mac 端联调

1. 安装并启动 `/Applications/VoiceRelay.app`，不要运行构建目录里的副本。菜单栏弹窗能看到 6 位配对码；二维码含 IP / 端口 / 配对码。
2. 手机「连接 Mac」页可自动发现、扫码、扫 BLE，或手填 IP。
3. 按住按钮说话，松手后文字出现在 Mac 当前光标处；注入失败时文字保留在手机结果卡，可手动复制，不会假报“已复制”。
4. 网络不稳时在 Mac 设置里打开「蓝牙备用通道」，手机端扫描 BLE 后连接。

## 结构

```
lib/
├── main.dart
├── protocol/       帧格式、HMAC、客户端状态机
├── transport/      TCP / BLE 抽象
├── discovery/      mDNS、BLE 扫描
├── audio/          录音
├── screen/         屏幕共享客户端
├── state/          全局状态、历史
└── ui/             主界面、设置、扫码、控制面板、屏幕观看
```

## 已知限制

- Opus 编码未启用（V1 走 PCM16，约 256 kbps；Mac 端已支持解码，协议字段已留）。
- iOS 后台保活、Android 前台服务未实现。
- 界面是同一视觉语言下的功能版，未逐像素还原 13 个原型画板。
- iOS 真机、BLE 硬件、屏幕视频播放仍待验收。
