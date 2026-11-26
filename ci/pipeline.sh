#!/usr/bin/env bash
# 从原版 IPA 走到 arm64 IPA 的全部构建步骤。
# 失败时把日志推到 ci-logs 分支，成功时把 IPA 挂到 build release，方便下载核对。
set -euo pipefail
cd "$(dirname "$0")/.."

RAW=ci-raw.log
LOG=build-log.md
IPA=FlyMe2theMoon-v1.7.0-arm64.ipa
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
    git add -f smoke-*.png smoke-*.txt >/dev/null 2>&1 || true
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

# ── 4.5 模拟器冒烟测试（建议性，不阻断打包）────────────────────────────
log "模拟器冒烟测试（建议性）"
bash ci/smoke.sh || true

# ── 5. 打包 IPA ────────────────────────────────────────────────────────
log "打包 IPA"
rm -rf Payload "$IPA"
mkdir -p Payload
cp -R "$APP_PATH" Payload/
# xcodebuild 关掉签名时，ld 仍会留下 linker 签名（分页哈希有效，但 Info.plist / CodeResources 槽为空），
# 第三方签名工具预检 embedded 签名时会判定失败并中止。所以先清掉旧签名，再用 codesign 打一份完整的 ad-hoc 签名。
codesign --remove-signature "Payload/FlyMe2theMoon.app" 2>&1 | tail -2 || true
codesign --remove-signature "Payload/FlyMe2theMoon.app/FlyMe2theMoon" 2>&1 | tail -2 || true
rm -rf "Payload/FlyMe2theMoon.app/_CodeSignature"
# 签名是否有效以 Apple 自己的 codesign --verify 为准；
# check_signature.py 只打印结构细节并交叉验证（解析器若出错也不会误杀正确签名）。
xattr -cr "Payload/FlyMe2theMoon.app" 2>/dev/null || true
set +e
codesign --force --sign - --identifier com.mihoyo.flyme2themoon.arm64 --timestamp=none \
  "Payload/FlyMe2theMoon.app" > sign.out 2>&1
CS=$?
codesign --verify --strict --verbose=4 "Payload/FlyMe2theMoon.app" > verify.out 2>&1
VF=$?
codesign -dvvv "Payload/FlyMe2theMoon.app" > desc.out 2>&1
set -e
echo "codesign exit=$CS  codesign --verify exit=$VF"
echo "--- codesign 输出 ---"
tail -25 sign.out || true
echo "--- codesign --verify ---"
cat verify.out || true
echo "--- CodeDirectory 概览 ---"
grep -E "Identifier|Format|CodeDirectory|CDHash|Signature|TeamIdentifier|Sealed Resources|Internal Error" desc.out || true
echo "sha256(Info.plist)=$(shasum -a 256 "Payload/FlyMe2theMoon.app/Info.plist" | cut -d' ' -f1)"
echo "--- 补写前：codesign 特殊槽 ---"
codesign --display -vvvvvv "Payload/FlyMe2theMoon.app" 2>&1 | grep -E '^-?[0-9]+=|Bound|Info.plist' || true
$PY ci/check_signature.py "Payload/FlyMe2theMoon.app" || true

# codesign 对 iOS 扁平 bundle 做 ad-hoc 签名时可能不绑定 Info.plist（slot -1 全零），
# 全能签这类重签工具预检会报 “Info.plist无效”。ad-hoc 无 CMS 密文，补齐 slot -1 后结构即自洽。
rm -rf /tmp/app_backup
cp -R "Payload/FlyMe2theMoon.app" /tmp/app_backup
PATCH_RC=0
$PY ci/fix_infoplist_slot.py "Payload/FlyMe2theMoon.app" || PATCH_RC=$?
echo "--- 补写后：codesign 特殊槽 ---"
codesign --display -vvvvvv "Payload/FlyMe2theMoon.app" 2>&1 | grep -E '^-?[0-9]+=|Bound|Info.plist' || true
codesign --verify --strict --verbose=4 "Payload/FlyMe2theMoon.app" > verify2.out 2>&1
VF2=$?
SC=0
$PY ci/check_signature.py "Payload/FlyMe2theMoon.app" || SC=$?
echo "patch exit=$PATCH_RC  verify(after patch) exit=$VF2  check_signature exit=$SC"
cat verify2.out || true

if [ "$PATCH_RC" -ne 0 ]; then
  echo "!! 补写 slot -1 失败，回退到补写前的签名产物"
  rm -rf "Payload/FlyMe2theMoon.app"
  cp -R /tmp/app_backup "Payload/FlyMe2theMoon.app"
fi
rm -rf /tmp/app_backup

if [ "$CS" -eq 0 ] && [ "$VF" -eq 0 ] && [ "$PATCH_RC" -eq 0 ] && [ "$VF2" -eq 0 ] && [ "$SC" -eq 0 ]; then
  echo "签名有效且自洽：codesign --verify --strict 通过，Info.plist 已绑定"
  SIGN_STATE="ad-hoc 签名有效（Info.plist 已绑定）"
else
  echo "!! 未能产出有效签名（codesign=$CS verify=$VF patch=$PATCH_RC verify2=$VF2 selfcheck=$SC），回退为完全未签名"
  codesign --remove-signature "Payload/FlyMe2theMoon.app" 2>&1 | tail -2 || true
  codesign --remove-signature "Payload/FlyMe2theMoon.app/FlyMe2theMoon" 2>&1 | tail -2 || true
  rm -rf "Payload/FlyMe2theMoon.app/_CodeSignature"
  $PY ci/check_signature.py "Payload/FlyMe2theMoon.app" || true
  SIGN_STATE="完全未签名（主程序无 LC_CODE_SIGNATURE）"
fi
echo "交付形态：$SIGN_STATE"
# IPA 规范结构：zip 根目录下必须是 Payload/xxx.app
rm -f "$IPA"
zip -qry "$IPA" Payload

ls -lh "$IPA"
unzip -l "$IPA" | head -8
$PY ci/check_ipa.py "$IPA"

# ── 6. 发布到 build release，方便下载核对 ──────────────────────────────
if [ -n "${GH_TOKEN:-}" ]; then
  log "上传 release"
  ASSET="FlyMe2theMoon-v1.7.0-arm64.ipa"
  gh release view build >/dev/null 2>&1 || gh release create build --title "arm64 构建产物" --notes "由 GitHub Actions 自动构建，arm64，不含开发者证书（ad-hoc 签名由 codesign 完成，Info.plist 已绑定）。" || true
  gh release delete-asset build "FlyMe2theMoon-v1.7.0-arm64-unsigned.ipa" --yes >/dev/null 2>&1 || true
  gh release upload build "$IPA" --clobber || echo "!! release 上传失败"
fi

push_log "success"
echo "完成：$IPA"
