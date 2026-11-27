# 打包与发布

本文写给维护者。所有命令都在仓库根目录执行。

## 版本号

一次发布只改这三处：

- `CHANGELOG.md` 增加版本段落
- `VERSION` 环境变量（打包时传入，默认 `1.0.0`）
- `mobile/voicerelay/pubspec.yaml` 的 `version`（影响 APK versionName/versionCode）

## 构建安装包

### DMG

```bash
cd mac
VERSION=1.0.0 BUILD_NUMBER=1 ./scripts/package-dmg.sh
# 产物：mac/build/VoiceRelay-1.0.0.dmg
```

脚本会：

1. `swift build -c release`
2. 组装 `VoiceRelay.app`，拷入 `libsherpa-onnx-c-api.dylib`、`libonnxruntime.dylib`、`WebRTC.framework`
3. 写入带版本号的 `Info.plist`
4. 签名（默认 ad-hoc，可用 `CODESIGN_IDENTITY` 覆盖）
5. 用 `hdiutil` 生成压缩 DMG，并打印 SHA-256

**签名与公证**

- 没有证书时用 ad-hoc（`-`）。用户首次打开需要右键 → 打开。
- 有 Apple Development 证书只能本机/团队测试，跨机器仍会被 Gatekeeper 拦。
- 正式分发建议 Developer ID：

  ```bash
  CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package-dmg.sh
  xcrun notarytool submit build/VoiceRelay-1.0.0.dmg \
    --apple-id you@example.com --team-id TEAMID --password app-specific-password --wait
  xcrun stapler staple build/VoiceRelay-1.0.0.dmg
  ```

  公证需要付费 Apple Developer Program；本项目当前未配置。

### APK

```bash
./mobile/scripts/build-apk.sh
# 产物：mobile/voicerelay/build/dist/VoiceRelay-1.0.0.apk
```

当前 `android/app/build.gradle.kts` 的 release 使用 debug 签名，便于侧载。要正式分发，创建 keystore 后：

1. 在 `mobile/voicerelay/android/key.properties` 写入（**不要提交**）：

   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=voicerelay
   storeFile=/absolute/path/to/voicerelay-release.jks
   ```

2. 在 `android/app/build.gradle.kts` 里读取该文件并配置 `signingConfigs.release`，替换 `signingConfig = signingConfigs.getByName("debug")`。
3. 把 keystore 与密码放进密码管理器并离线备份。**同一应用升级必须使用同一把 key**，丢失后用户只能卸载重装。

> 如果你 fork 后自行发布，请改掉 `applicationId`，否则会和本项目的安装包冲突。

## 发布到 GitHub

```bash
git tag v1.0.0
git push origin v1.0.0
gh release create v1.0.0 \
  mac/build/VoiceRelay-1.0.0.dmg \
  mobile/voicerelay/build/dist/VoiceRelay-1.0.0.apk \
  --title "VoiceRelay 1.0.0" \
  --notes-file CHANGELOG.md
```

发布前检查：

- [ ] `swift test`、`flutter analyze`、`flutter test` 全绿
- [ ] DMG 挂载后能拖拽安装，`codesign --verify --deep --strict` 通过
- [ ] APK `aapt dump badging` 的包名、版本、权限正确
- [ ] 在干净的 macOS 用户/机器上试装一次（至少换路径）
- [ ] 不包含模型权重、keystore、个人路径
- [ ] Release Notes 写清已知限制与未公证提示

## 自动化

`.github/workflows/ci.yml` 在 push/PR 时跑 macOS 单元测试与 Flutter 静态检查/测试。
`.github/workflows/release.yml` 需在 Actions 页面手动触发（填入版本号），构建 DMG 与 APK 并附加到 Draft Release；不会与本地发布或已有 tag 自动冲突。

CI 构建的 APK 使用 runner 的 debug key，和本地签名不同，**不能覆盖安装**；正式发布仍建议本地出包后上传。
