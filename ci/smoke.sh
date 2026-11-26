#!/usr/bin/env bash
# 模拟器冒烟测试（建议性，不阻断打包）：能装能启动 10 秒不退出，并留截图。
# 依赖 pipeline.sh 已铺好的 Resources/ 与 Sources/lua/。
set -uo pipefail
cd "$(dirname "$0")/.."

BID=com.mihoyo.flyme2themoon.arm64
SHOT=smoke-menu.png
FAIL=smoke-fail.txt
rm -f "$SHOT" "$FAIL"

note_fail() { echo "$*" | tee -a "$FAIL"; }

echo "===== 模拟器构建 ====="
rm -rf build-sim
xcodebuild \
  -project FlyMe2theMoon.xcodeproj \
  -scheme FlyMe2theMoon \
  -configuration Debug \
  -sdk iphonesimulator \
  -derivedDataPath build-sim \
  ARCHS=arm64 \
  PRODUCT_BUNDLE_IDENTIFIER="$BID" \
  GENERATE_INFOPLIST_FILE=YES \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build 2>&1 | tail -25
SIM_APP=build-sim/Build/Products/Debug-iphonesimulator/FlyMe2theMoon.app
if [ ! -d "$SIM_APP" ]; then note_fail "模拟器产物缺失"; exit 0; fi

echo "===== 启动模拟器 ====="
xcrun simctl list devices available | grep -E "iPhone 16" | head -3
UDID=$(xcrun simctl list devices available | grep -m1 -E "iPhone 16 \(" | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')
if [ -z "$UDID" ]; then note_fail "找不到 iPhone 16 模拟器"; exit 0; fi
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

ls -l "$SIM_APP"
plutil -p "$SIM_APP/Info.plist" | grep -E "CFBundleIdentifier|CFBundleSupportedPlatforms|CFBundleExecutable" || note_fail "Info.plist 关键键缺失"

# 不要 --deep：--deep 签名会让 app 的 Info.plist 变成 not bound，simctl 就取不到 bundle id
codesign --force --sign - --identifier "$BID" "$SIM_APP" 2>&1 | tail -3 || true
codesign -dv "$SIM_APP" 2>&1 | head -6 || true

if ! xcrun simctl install "$UDID" "$SIM_APP"; then
  note_fail "simctl install 失败（不影响打包）"
  exit 0
fi
if ! OUT=$(xcrun simctl launch "$UDID" "$BID"); then
  note_fail "simctl launch 失败"
  exit 0
fi
echo "launch: $OUT"
sleep 10
xcrun simctl io "$UDID" screenshot "$SHOT" 2>/dev/null || note_fail "截图失败"
ls -l "$SHOT" 2>/dev/null || true

if xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -q "$BID"; then
  echo "SMOKE_OK 进程 10 秒后仍存活"
else
  note_fail "进程已退出（可能崩溃）"
  ls -t ~/Library/Logs/DiagnosticReports 2>/dev/null | head -5 || true
  xcrun simctl spawn "$UDID" log show --last 2m --style compact \
    --predicate 'process == "FlyMe2theMoon"' 2>/dev/null | tail -40 | tee -a "$FAIL" || true
fi
exit 0
