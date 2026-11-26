#!/usr/bin/env bash
# 模拟器冒烟测试：证明产物能装、能启动、10 秒内不退出，并留下截图证据。
# 依赖 pipeline.sh 已铺好的 Resources/ 与 Sources/lua/。
set -euo pipefail
cd "$(dirname "$0")/.."

BID=com.mihoyo.flyme2themoon.arm64
SHOT=smoke-menu.png
rm -f "$SHOT"

echo "===== 模拟器构建 ====="
rm -rf build-sim
xcodebuild \
  -project FlyMe2theMoon.xcodeproj \
  -scheme FlyMe2theMoon \
  -configuration Debug \
  -sdk iphonesimulator \
  -derivedDataPath build-sim \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build | tail -20
SIM_APP=build-sim/Build/Products/Debug-iphonesimulator/FlyMe2theMoon.app
test -d "$SIM_APP" || { echo "!! 模拟器产物缺失"; false; }

echo "===== 启动模拟器 ====="
xcrun simctl list devices available | grep -E "iPhone 16" | head -3
UDID=$(xcrun simctl list devices available | grep -m1 -E "iPhone 16 \(" | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')
test -n "$UDID" || { echo "!! 找不到 iPhone 16 模拟器"; false; }
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

xcrun simctl install "$UDID" "$SIM_APP"
OUT=$(xcrun simctl launch "$UDID" "$BID")
echo "launch: $OUT"
PID=$(echo "$OUT" | awk '{print $NF}')
sleep 10

xcrun simctl io "$UDID" screenshot "$SHOT" 2>/dev/null || echo "!! 截图失败"
ls -l "$SHOT" 2>/dev/null || true

if xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -q "$BID"; then
  echo "SMOKE_OK pid=$PID 进程 10 秒后仍存活"
else
  echo "!! 进程已退出（崩溃）"
  ls -t ~/Library/Logs/DiagnosticReports 2>/dev/null | head -5 || true
  xcrun simctl spawn "$UDID" log show --last 2m --style compact \
    --predicate 'process == "FlyMe2theMoon"' 2>/dev/null | tail -40 || true
  false
fi
