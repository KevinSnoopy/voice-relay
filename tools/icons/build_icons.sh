#!/bin/bash
# 从矢量母版重新生成 VoiceRelay 全部平台图标。
#   bash tools/icons/build_icons.sh
# 图形真源 = tools/icons/render_icon.swift；改造型只改那一个文件。
set -euo pipefail
cd "$(dirname "$0")/../.."

OUT="tools/icons/out"
MOBILE="mobile/voicerelay"
RES="$MOBILE/android/app/src/main/res"
ICON_DIR="$MOBILE/assets/icon"

render() { # 路径 尺寸 模式
  mkdir -p "$(dirname "$1")"
  swift tools/icons/render_icon.swift "$1" "$2" "$3"
}

# ---------- macOS：.icns ----------
ICONSET="$OUT/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
while read -r size name; do
  render "$ICONSET/$name.png" "$size" mac
done <<'EOF'
16 icon_16x16
32 icon_16x16@2x
32 icon_32x32
64 icon_32x32@2x
128 icon_128x128
256 icon_128x128@2x
256 icon_256x256
512 icon_256x256@2x
512 icon_512x512
1024 icon_512x512@2x
EOF
mkdir -p mac/Resources
iconutil -c icns "$ICONSET" -o mac/Resources/AppIcon.icns
render mac/Resources/AppIcon.png 1024 mac
echo "==> mac/Resources/AppIcon.icns"

# ---------- Android：旧版 PNG + 自适应图标 ----------
while read -r dpi legacy foreground; do
  render "$RES/mipmap-$dpi/ic_launcher.png" "$legacy" android
  render "$RES/mipmap-$dpi/ic_launcher_foreground.png" "$foreground" adaptive
done <<'EOF'
mdpi 48 108
hdpi 72 162
xhdpi 96 216
xxhdpi 144 324
xxxhdpi 192 432
EOF
mkdir -p "$RES/mipmap-anydpi-v26" "$RES/drawable"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML
cat > "$RES/drawable/ic_launcher_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="315" android:startColor="#3B82F6" android:endColor="#1E40AF"/>
</shape>
XML
echo "==> $RES/mipmap-*/ + mipmap-anydpi-v26 + drawable/ic_launcher_background.xml"

# ---------- iOS：AppIcon.appiconset（iOS 平台尚未 scaffold，先备料） ----------
APPICON="$ICON_DIR/AppIcon.appiconset"
rm -rf "$APPICON"
mkdir -p "$APPICON"
render "$ICON_DIR/app_icon.png" 1024 ios
while read -r name size; do
  render "$APPICON/$name.png" "$size" ios
done <<'EOF'
Icon-20@1x 20
Icon-20@2x 40
Icon-20@3x 60
Icon-29@1x 29
Icon-29@2x 58
Icon-29@3x 87
Icon-40@1x 40
Icon-40@2x 80
Icon-40@3x 120
Icon-60@2x 120
Icon-60@3x 180
Icon-76@1x 76
Icon-76@2x 152
Icon-83.5@2x 167
Icon-1024 1024
EOF
cat > "$APPICON/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "Icon-20@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "20x20" },
    { "filename" : "Icon-20@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "20x20" },
    { "filename" : "Icon-29@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "filename" : "Icon-29@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "filename" : "Icon-40@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "filename" : "Icon-40@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "filename" : "Icon-60@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "filename" : "Icon-60@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },
    { "filename" : "Icon-20@1x.png", "idiom" : "ipad", "scale" : "1x", "size" : "20x20" },
    { "filename" : "Icon-20@2x.png", "idiom" : "ipad", "scale" : "2x", "size" : "20x20" },
    { "filename" : "Icon-29@1x.png", "idiom" : "ipad", "scale" : "1x", "size" : "29x29" },
    { "filename" : "Icon-29@2x.png", "idiom" : "ipad", "scale" : "2x", "size" : "29x29" },
    { "filename" : "Icon-40@1x.png", "idiom" : "ipad", "scale" : "1x", "size" : "40x40" },
    { "filename" : "Icon-40@2x.png", "idiom" : "ipad", "scale" : "2x", "size" : "40x40" },
    { "filename" : "Icon-76@1x.png", "idiom" : "ipad", "scale" : "1x", "size" : "76x76" },
    { "filename" : "Icon-76@2x.png", "idiom" : "ipad", "scale" : "2x", "size" : "76x76" },
    { "filename" : "Icon-83.5@2x.png", "idiom" : "ipad", "scale" : "2x", "size" : "83.5x83.5" },
    { "filename" : "Icon-1024.png", "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : { "author" : "voicerelay", "version" : 1 }
}
JSON
echo "==> $APPICON"

# iOS 平台已 scaffold 时，顺手装进 Xcode 工程
if [ -d "$MOBILE/ios/Runner/Assets.xcassets" ]; then
  rm -rf "$MOBILE/ios/Runner/Assets.xcassets/AppIcon.appiconset"
  cp -R "$APPICON" "$MOBILE/ios/Runner/Assets.xcassets/AppIcon.appiconset"
  echo "==> 已安装到 ios/Runner/Assets.xcassets/AppIcon.appiconset"
fi
