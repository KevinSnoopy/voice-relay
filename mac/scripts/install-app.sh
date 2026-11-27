#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="${1:-/Applications/VoiceRelay.app}"

./scripts/build-app.sh release

python3 - "$DEST" <<'PY'
import pathlib, shutil, sys
dest = pathlib.Path(sys.argv[1])
if dest.exists():
    shutil.rmtree(dest)
PY

cp -R build/VoiceRelay.app "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
echo "==> installed: $DEST"
echo "首次安装/换签名后如仍提示未授权，执行一次："
echo "  tccutil reset Accessibility com.voicerelay.app"
echo "然后在 系统设置 › 隐私与安全性 › 辅助功能 勾选 VoiceRelay，再重启 App。"
open "$DEST"
