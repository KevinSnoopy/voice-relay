#!/bin/bash
# Builds VoiceRelay.app and packs it into a distributable DMG.
#
#   ./scripts/package-dmg.sh            # uses VERSION=1.0.0
#   VERSION=1.1.0 ./scripts/package-dmg.sh
#
# Set CODESIGN_IDENTITY to a Developer ID / Apple Development identity if you
# have one; otherwise the app is ad-hoc signed (works locally, but macOS will
# ask the user to confirm the first launch).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
export VERSION BUILD_NUMBER CODESIGN_IDENTITY

./scripts/build-app.sh release

APP="build/VoiceRelay.app"
STAGE="build/dmg"
DMG="build/VoiceRelay-${VERSION}.dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/VoiceRelay.app"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/首次打开说明.txt" <<'TXT'
VoiceRelay 安装说明
==================

1. 把 VoiceRelay.app 拖进 Applications 文件夹。

2. 首次打开如果提示“无法验证开发者”：
   在 Finder 里右键 VoiceRelay → 打开 → 再点“打开”；
   或到 系统设置 › 隐私与安全性，点“仍要打开”。

3. 按 App 内的引导：
   - 授予“辅助功能”权限（必须，用于把文字写进当前输入框）；
   - 下载语音模型（约 155 MB，只需一次）；
   - 手机安装 VoiceRelay APK 或 iOS 版源码构建，扫码配对。

注意：本安装包未做 Apple 公证，所以首次打开需要手动确认。
TXT

echo "==> hdiutil"
hdiutil create \
  -volname "VoiceRelay ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG"

echo "==> $DMG"
shasum -a 256 "$DMG"
