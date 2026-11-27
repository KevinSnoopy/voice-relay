#!/bin/bash
# Downloads the prebuilt sherpa-onnx runtime used by the macOS target.
# Binaries are not committed to keep clones small; WebRTC.xcframework is.
set -euo pipefail
cd "$(dirname "$0")/.."

LIB_DIR="vendor/sherpa-onnx-v2.0.3-osx-x64-shared"

if [ -f "$LIB_DIR/lib/libsherpa-onnx-c-api.dylib" ] && [ -f "$LIB_DIR/lib/libonnxruntime.dylib" ]; then
  echo "sherpa-onnx 已就绪: $LIB_DIR"
  exit 0
fi

mkdir -p vendor
echo "==> 下载 sherpa-onnx 2.0.3 (osx-x64, 约 23 MB)"
curl -L --retry 3 --fail -o vendor/sherpa-shared.tar.bz2 \
  https://github.com/k2-fsa/sherpa-onnx/releases/download/v2.0.3/sherpa-onnx-v2.0.3-osx-x64-shared.tar.bz2
tar xjf vendor/sherpa-shared.tar.bz2 -C vendor
rm -f vendor/sherpa-shared.tar.bz2
echo "完成: $LIB_DIR"
