#!/usr/bin/env bash
# 诊断脚本：不同 codesign 参数下 Info.plist 是否被绑定（CodeDirectory slot -1 是否非零）。
# 用法：bash ci/sign_probe.sh <FlyMe2theMoon.app> [python]
set -uo pipefail
SRC=${1:?用法：bash ci/sign_probe.sh <app> [python]}
PY=${2:-python3}

probe() {
  local label="$1" pre="$2"
  shift 2
  rm -rf /tmp/FlyMe2theMoon.app
  cp -R "$SRC" /tmp/FlyMe2theMoon.app
  xattr -cr /tmp/FlyMe2theMoon.app 2>/dev/null || true
  if [ "$pre" = "xml" ]; then
    plutil -convert xml1 /tmp/FlyMe2theMoon.app/Info.plist
  fi
  codesign --force --sign - "$@" /tmp/FlyMe2theMoon.app > /tmp/probe.out 2>&1
  local rc=$?
  echo "---- [$label] codesign exit=$rc $*"
  sed -n '1,6p' /tmp/probe.out 2>/dev/null | sed 's/^/     /'
  codesign -dvvv /tmp/FlyMe2theMoon.app 2>&1 \
    | grep -E "Identifier=|Format=|Info.plist|Sealed Resources|CDHash=|CodeDirectory v" | sed 's/^/     /'
  $PY ci/check_signature.py /tmp/FlyMe2theMoon.app 2>/dev/null \
    | grep -E "^CodeDirectory|Info.plist 槽|CodeResources 槽|分页哈希" | sed 's/^/     /'
}

probe "1 默认" none
probe "2 默认 + XML Info.plist" xml
probe "3 --preserve-metadata=identifier" none --preserve-metadata=identifier
probe "4 --identifier <bundleid>" none --identifier com.mihoyo.flyme2themoon.arm64
probe "5 默认 + --timestamp=none" none --timestamp=none
probe "6 --identifier + --preserve-metadata=identifier" none \
  --identifier com.mihoyo.flyme2themoon.arm64 --preserve-metadata=identifier

rm -rf /tmp/FlyMe2theMoon.app
