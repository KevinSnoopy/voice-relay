#!/bin/bash
# Downloads the SenseVoice int8 model used by the macOS app.
# The app can also download it on first launch (Settings → 模型).
set -euo pipefail
cd "$(dirname "$0")/.."

MODEL_DIR="$HOME/Library/Application Support/VoiceRelay/models"
mkdir -p "$MODEL_DIR"

./scripts/fetch-deps.sh

if [ ! -d "$MODEL_DIR/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17" ]; then
  echo "==> 下载 SenseVoice int8（约 155 MB）"
  curl -L --retry 3 --fail -o "$MODEL_DIR/sensevoice-int8.tar.bz2" \
    https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2
  tar xjf "$MODEL_DIR/sensevoice-int8.tar.bz2" -C "$MODEL_DIR"
  rm -f "$MODEL_DIR/sensevoice-int8.tar.bz2"
else
  echo "模型已存在: $MODEL_DIR/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"
fi

echo "完成。模型目录: $MODEL_DIR"
