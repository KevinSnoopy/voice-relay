#!/bin/bash
# Downloads the prebuilt sherpa-onnx runtime used by the macOS target.
# Binaries are not committed to keep clones small; WebRTC.xcframework is.
set -euo pipefail
cd "$(dirname "$0")/.."

for ARCH in x64 arm64; do
  LIB_DIR="vendor/sherpa-onnx-v2.0.3-osx-${ARCH}-shared"
  if [ -f "$LIB_DIR/lib/libsherpa-onnx-c-api.dylib" ] && [ -f "$LIB_DIR/lib/libonnxruntime.dylib" ]; then
    echo "sherpa-onnx 已就绪: $LIB_DIR"
    continue
  fi

  mkdir -p vendor
  echo "==> 下载 sherpa-onnx 2.0.3 (osx-${ARCH}, 约 23 MB)"
  curl -L --retry 3 --fail -o "vendor/sherpa-shared-${ARCH}.tar.bz2" \
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/v2.0.3/sherpa-onnx-v2.0.3-osx-${ARCH}-shared.tar.bz2"
  tar xjf "vendor/sherpa-shared-${ARCH}.tar.bz2" -C vendor
  rm -f "vendor/sherpa-shared-${ARCH}.tar.bz2"
  echo "完成: $LIB_DIR"
done
echo "完成"
