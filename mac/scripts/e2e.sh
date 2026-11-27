#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CODE="${1:-123456}"
TEXT="${2:-把第三段的标题改短一点，下面两行跟上节奏。}"

swift build
./.build/debug/voicerelayd --pairing-code "$CODE" > /tmp/voicerelay-e2e.log 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
for _ in $(seq 1 90); do
  grep -q "监听" /tmp/voicerelay-e2e.log 2>/dev/null && break
  sleep 1
done
./.build/debug/vrphone --code "$CODE" --say "$TEXT" --timeout 30
