#!/bin/bash
# Builds a universal release APK (all ABIs) plus per-ABI splits.
#
#   ./scripts/build-apk.sh
#
# Requires Flutter 3.38.x (see mobile/voicerelay/.fvmrc) and Android SDK.
# Release builds currently use the debug signing key, which is fine for
# sideloading but not for Play Store distribution. See docs/OPEN-SOURCE.md.
set -euo pipefail
cd "$(dirname "$0")/../voicerelay"

if [ -n "${JAVA_HOME:-}" ]; then
  :
elif [ -x "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java" ]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi

FLUTTER="${FLUTTER:-$(command -v flutter || true)}"
if [ -z "$FLUTTER" ]; then
  for candidate in "$HOME/fvm/versions/3.38.9/bin/flutter" "$HOME/.fvm/versions/3.38.9/bin/flutter"; do
    if [ -x "$candidate" ]; then FLUTTER="$candidate"; break; fi
  done
fi
if [ -z "$FLUTTER" ]; then
  echo "找不到 flutter，请先安装 Flutter 3.38.x 或设置 FLUTTER=/path/to/flutter" >&2
  exit 1
fi

export PATH="$(dirname "$FLUTTER"):$PATH"
flutter pub get
flutter build apk --release

mkdir -p build/dist
cp build/app/outputs/flutter-apk/app-release.apk build/dist/VoiceRelay-1.0.0.apk
echo "==> build/dist/VoiceRelay-1.0.0.apk"
