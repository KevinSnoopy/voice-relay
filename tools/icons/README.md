# 应用图标

图形真源是 `render_icon.swift`（Swift + CoreGraphics 矢量绘制，无第三方依赖）。
所有平台的图标都由它派生，改造型只改这一个文件。

```bash
bash tools/icons/build_icons.sh   # 重新生成全部平台图标
```

## 造型

蓝色渐变圆角方块 + 白色麦克风，对应 `docs/03-ui-mobile.md` M-01 的「圆角 28 渐变方块 + 麦克风」。
渐变 `#3B82F6 → #1E40AF`（品牌主色 `#2563eb` 的深浅两档），麦克风为纯白，保证 16px 下仍可辨认。

## 产物

| 平台 | 产物 | 说明 |
|---|---|---|
| macOS | `mac/Resources/AppIcon.icns` | 10 档尺寸（16→1024）；`build-app.sh` 拷进 `Contents/Resources/`，`Info.plist` 写 `CFBundleIconFile` |
| Android | `android/app/src/main/res/mipmap-*/ic_launcher.png` | 旧版 launcher，48→192 |
| Android | `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png` | 自适应图标前景，108→432（安全区内） |
| Android | `res/mipmap-anydpi-v26/ic_launcher.xml` + `res/drawable/ic_launcher_background.xml` | API 26+ 自适应图标，背景为同款渐变 |
| iOS | `mobile/voicerelay/assets/icon/AppIcon.appiconset/` | 15 档 20→1024，脚本同时装进 `ios/Runner/Assets.xcassets/` |
| 通用 | `mobile/voicerelay/assets/icon/app_icon.png` | 1024 母版（无 alpha） |

## 注意

- `.gitignore` 忽略了 `mobile/voicerelay/android/` 和 `mobile/voicerelay/ios/`，
  所以**新克隆后要重跑一次 `build_icons.sh`** 才有图标；
  `mobile/voicerelay/assets/icon/` 是提交进仓库的备份，可直接拷进任意平台目录。
- iOS 图标不能带 alpha 通道，渲染器用 `ios` 模式（不透明背景）生成。
- `iconutil` 输出目录必须先存在，否则报 `Failed to generate ICNS`。
