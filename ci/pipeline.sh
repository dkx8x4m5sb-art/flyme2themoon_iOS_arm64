#!/usr/bin/env bash
# 从原版 IPA 走到未签名 arm64 IPA 的全部构建步骤。
# 失败时把日志推到 ci-logs 分支，成功时把 IPA 挂到 build release，方便下载核对。
set -euo pipefail
cd "$(dirname "$0")/.."

RAW=ci-raw.log
LOG=build-log.md
IPA=FlyMe2theMoon-unsigned.ipa
: > "$RAW"
exec > >(tee -a "$RAW") 2>&1

log() { printf '\n===== %s =====\n' "$*"; }

push_log() {
  local outcome="$1"
  {
    echo "# outcome: $outcome"
    echo "# commit: ${GITHUB_SHA:-local}"
    echo "# time: $(date -u +%FT%TZ)"
    echo
    echo "----- errors -----"
    grep -E "error:|Error:|fatal error|No such file|not found|BUILD (SUCCEEDED|FAILED)" "$RAW" 2>/dev/null | tail -120 || true
    echo
    echo "----- tail -----"
    tail -80 "$RAW" 2>/dev/null || true
  } > "$LOG"
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git config user.name "fm-ci" || true
    git config user.email "fm-ci@users.noreply.github.com" || true
    git checkout --orphan ci-logs 2>/dev/null || git checkout ci-logs 2>/dev/null || true
    git rm -rf --cached . >/dev/null 2>&1 || true
    git add -f "$LOG" >/dev/null 2>&1 || true
    git add -f smoke-*.png >/dev/null 2>&1 || true
    git commit -m "ci: ${GITHUB_SHA:-local}" >/dev/null 2>&1 || true
    git push origin ci-logs --force >/dev/null 2>&1 || echo "!! push ci-logs failed"
  fi
}

on_error() {
  local code=$?
  echo "::error::构建失败（${code}），命令：${BASH_COMMAND}"
  push_log "failure"
  exit "$code"
}
trap on_error ERR

# ── 0. 依赖 ────────────────────────────────────────────────────────────
log "依赖：xcodegen / pillow"
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi
PY=python3
if ! python3 -c "import PIL" >/dev/null 2>&1; then
  python3 -m venv .venv || true
  if [ -x .venv/bin/pip ]; then
    .venv/bin/pip install --quiet --upgrade pip >/dev/null 2>&1 || true
    .venv/bin/pip install --quiet pillow
  else
    python3 -m pip install --quiet --user pillow || python3 -m pip install --quiet --break-system-packages pillow
  fi
fi
if [ -x .venv/bin/python ] && .venv/bin/python -c "import PIL" >/dev/null 2>&1; then
  PY=.venv/bin/python
fi
$PY -c "import PIL; print('pillow', PIL.__version__)"

# ── 0.5 Lua 5.1.5 源码（不进 git）──────────────────────────────────────
log "Lua 5.1.5"
if [ ! -f Sources/lua/lapi.c ]; then
  curl -fL --retry 3 --retry-delay 2 -o lua515.tgz https://www.lua.org/ftp/lua-5.1.5.tar.gz
  rm -rf lua-5.1.5
  tar xzf lua515.tgz
  rm -f Sources/lua/.keep
  cp lua-5.1.5/src/*.c lua-5.1.5/src/*.h Sources/lua/
  rm -f Sources/lua/lua.c Sources/lua/luac.c Sources/lua/liolib.c Sources/lua/loslib.c Sources/lua/loadlib.c Sources/lua/linit.c
fi
ls Sources/lua | head -5

# ── 1. 取原版素材包 ────────────────────────────────────────────────────
log "下载并解包 IPA"
rm -rf ipa unpacked
mkdir -p ipa
curl -fL --retry 3 --retry-delay 2 -o ipa/source.ipa "${IPA_URL:?IPA_URL 未设置}"
unzip -q ipa/source.ipa -d unpacked
APP=$(find unpacked/Payload -maxdepth 1 -name '*.app' -type d | head -1)
test -n "$APP" || { echo "!! 解包后没有 .app"; false; }
echo "素材来源: $APP"

# ── 2. 铺素材 + 图集转正 ───────────────────────────────────────────────
log "重建资源"
rm -rf Resources
$PY ci/prepare_assets.py "$APP" Resources
$PY ci/verify_data.py Resources

# ── 3. 生成工程并编译 ──────────────────────────────────────────────────
log "xcodegen"
xcodegen generate

log "xcodebuild"
rm -rf build
set +e
xcodebuild \
  -project FlyMe2theMoon.xcodeproj \
  -scheme FlyMe2theMoon \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
BUILD_STATUS=$?
set -e
echo "xcodebuild exit=$BUILD_STATUS"
[ "$BUILD_STATUS" -eq 0 ] || { echo "::error::xcodebuild 失败"; exit "$BUILD_STATUS"; }

# ── 4. 架构与结构校验 ──────────────────────────────────────────────────
log "校验产物"
APP_PATH="build/Build/Products/Release-iphoneos/FlyMe2theMoon.app"
test -d "$APP_PATH" || { echo "!! 没有产物 $APP_PATH"; false; }
test -f "$APP_PATH/FlyMe2theMoon" || { echo "!! 缺主程序"; false; }
MAIN_ARCH=$(xcrun lipo -info "$APP_PATH/FlyMe2theMoon")
echo "$MAIN_ARCH"
echo "$MAIN_ARCH" | grep -q arm64 || { echo "!! 主程序不是 arm64"; false; }

# app 内所有 Mach-O 都必须是 arm64（脚本/资源除外）
BAD=0
while IFS= read -r -d '' f; do
  if file "$f" | grep -q "Mach-O"; then
    info=$(xcrun lipo -info "$f" 2>/dev/null || true)
    echo "$(basename "$f"): $info"
    case "$info" in
      *arm64*) ;;
      *) echo "!! 非 arm64: $f"; BAD=1 ;;
    esac
  fi
done < <(find "$APP_PATH" -type f -print0)
[ "$BAD" -eq 0 ] || { echo "!! 存在非 arm64 的可执行文件"; false; }

plutil -p "$APP_PATH/Info.plist" | grep -E "CFBundleIdentifier|MinimumOSVersion|CFBundleExecutable" || true

# ── 4.5 模拟器冒烟测试 ────────────────────────────────────────────────
log "模拟器冒烟测试"
bash ci/smoke.sh

# ── 5. 打包 IPA ────────────────────────────────────────────────────────
log "打包未签名 IPA"
rm -rf Payload "$IPA"
mkdir -p Payload
cp -R "$APP_PATH" Payload/
plutil -convert xml1 "Payload/FlyMe2theMoon.app/Info.plist" 2>/dev/null || true
# ad-hoc 签名：方便第三方重签工具直接覆盖签名槽
codesign --force --deep --sign - "Payload/FlyMe2theMoon.app" 2>&1 | tail -3 || echo "!! ad-hoc 签名失败（继续）"
codesign -dv "Payload/FlyMe2theMoon.app" 2>&1 | head -5 || true
# IPA 规范结构：zip 根目录下必须是 Payload/xxx.app
rm -f "$IPA"
zip -qry "$IPA" Payload

ls -lh "$IPA"
unzip -l "$IPA" | head -8
unzip -l "$IPA" | grep -q "Payload/FlyMe2theMoon.app/Info.plist" || { echo "!! IPA 结构错误：缺少 Payload/ 顶层"; false; }

# ── 6. 发布到 build release，方便下载核对 ──────────────────────────────
if [ -n "${GH_TOKEN:-}" ]; then
  log "上传 release"
  ASSET="FlyMe2theMoon-v1.7.0-arm64-unsigned.ipa"
  cp "$IPA" "$ASSET"
  gh release view build >/dev/null 2>&1 || gh release create build --title "arm64 构建产物" --notes "由 GitHub Actions 自动构建，未签名。" || true
  gh release upload build "$ASSET" --clobber || echo "!! release 上传失败"
fi

push_log "success"
echo "完成：$IPA"
