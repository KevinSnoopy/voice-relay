#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
CONFIG="${1:-release}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG" --product VoiceRelay

BIN=".build/$CONFIG/VoiceRelay"
APP="build/VoiceRelay.app"
python3 - <<'PY'
import shutil, pathlib
app = pathlib.Path('build/VoiceRelay.app')
if app.exists():
    shutil.rmtree(app)
for sub in ['Contents/MacOS', 'Contents/Frameworks', 'Contents/Resources']:
    (app / sub).mkdir(parents=True, exist_ok=True)
PY

cp "$BIN" "$APP/Contents/MacOS/VoiceRelay"
cp vendor/sherpa-onnx-v2.0.3-osx-x64-shared/lib/libsherpa-onnx-c-api.dylib "$APP/Contents/Frameworks/"
cp vendor/sherpa-onnx-v2.0.3-osx-x64-shared/lib/libonnxruntime.dylib "$APP/Contents/Frameworks/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R vendor/WebRTC.xcframework/macos-x86_64/WebRTC.framework "$APP/Contents/Frameworks/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleExecutable</key><string>VoiceRelay</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.voicerelay.app</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>VoiceRelay</string>
    <key>CFBundleDisplayName</key><string>VoiceRelay</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>网络不通时用蓝牙连接手机，传输语音与按键。</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>在局域网内接收手机音频。</string>
    <key>NSBonjourServices</key>
    <array><string>_voicerelay._tcp</string></array>
</dict>
</plist>
PLIST

install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/VoiceRelay" 2>/dev/null || true
IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(.*\)"/\1/p' | head -1)"
fi
if [ -n "$IDENTITY" ]; then
  echo "==> codesign: $IDENTITY"
  codesign --force --deep --sign "$IDENTITY" "$APP"
else
  echo "==> codesign: ad-hoc (no identity found)"
  codesign --force --deep --sign - "$APP"
fi
echo "==> $APP"
echo "运行: open $APP"
