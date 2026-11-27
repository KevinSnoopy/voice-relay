#!/bin/bash
# Rebuilds vendor/LiveKitWebRTC.xcframework from LiveKit's published build.
#
# Google publishes no macOS arm64 WebRTC binary, so the arm64 target uses
# LiveKit's XCFramework (stock WebRTC headers compiled with LK type prefixes).
# The XCFramework is committed with only its macOS arm64 slice to keep clones
# small; run this script only when you want to bump the pinned version.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${LIVEKIT_WEBRTC_VERSION:-150.7871.09}"
SHA256="4ce3ba4041b94128c8e8bf7b2bc0ad9371af61dc65588b8023f4562db5c3c653"
URL="https://github.com/livekit/webrtc-xcframework/releases/download/${VERSION}/LiveKitWebRTC.xcframework.zip"
DEST="vendor/LiveKitWebRTC.xcframework"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> 下载 LiveKitWebRTC ${VERSION}（约 655 MB）"
curl -L --retry 3 --fail -o "$TMP/lk.zip" "$URL"

echo "==> 校验 sha256"
echo "${SHA256}  $TMP/lk.zip" | shasum -a 256 -c -

echo "==> 解压 macOS 切片"
unzip -q "$TMP/lk.zip" -d "$TMP/unzip"
SRC="$TMP/unzip/LiveKitWebRTC.xcframework"
rm -rf "$DEST"
mkdir -p "$DEST/macos-arm64"
cp -R "$SRC/macos-arm64_x86_64/LiveKitWebRTC.framework" "$DEST/macos-arm64/"
cp "$SRC/LICENSE" "$DEST/LICENSE"

echo "==> 只保留 arm64"
BIN="$DEST/macos-arm64/LiveKitWebRTC.framework/Versions/A/LiveKitWebRTC"
lipo -thin arm64 "$BIN" -output "$TMP/thin"
mv "$TMP/thin" "$BIN"
chmod +x "$BIN"

cat > "$DEST/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AvailableLibraries</key>
	<array>
		<dict>
			<key>BinaryPath</key>
			<string>LiveKitWebRTC.framework/LiveKitWebRTC</string>
			<key>LibraryIdentifier</key>
			<string>macos-arm64</string>
			<key>LibraryPath</key>
			<string>LiveKitWebRTC.framework</string>
			<key>SupportedArchitectures</key>
			<array>
				<string>arm64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>macos</string>
		</dict>
	</array>
	<key>CFBundlePackageType</key>
	<string>XFWK</string>
	<key>XCFrameworkFormatVersion</key>
	<string>1.0</string>
</dict>
</plist>
PLIST

echo "完成: $DEST（$(du -sh "$DEST" | cut -f1)）"
