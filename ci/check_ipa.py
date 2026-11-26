#!/usr/bin/env python3
"""校验 IPA 是否满足交付约定：结构、架构、资源齐全。

用法：python3 ci/check_ipa.py <ipa 路径>
失败时以非 0 退出，便于 CI 拦截。
"""
import plistlib
import struct
import sys
import zipfile
from collections import Counter

APP = 'Payload/FlyMe2theMoon.app'
MAIN = APP + '/FlyMe2theMoon'
BID = 'com.mihoyo.flyme2themoon.arm64'


def main() -> int:
    ipa = sys.argv[1]
    problems = []
    with zipfile.ZipFile(ipa) as z:
        names = z.namelist()
        if APP + '/Info.plist' not in names:
            print('!! 缺少 %s/Info.plist（Payload 顶层结构不对）' % APP)
            return 1
        info = plistlib.loads(z.read(APP + '/Info.plist'))
        exe = z.read(MAIN)
        counts = Counter()
        for n in names:
            if n.startswith(APP + '/Resources/data/lua/') and n.endswith('.lua'):
                counts['lua'] += 1
            elif n.startswith(APP + '/Resources/audio/') and n.endswith('.wav'):
                counts['wav'] += 1
            elif n.startswith(APP + '/Resources/atlas/') and n.endswith('.png'):
                counts['atlas'] += 1
        signed_entries = [n for n in names if '_CodeSignature' in n]
        entries = len(names)

    # Mach-O 头与 load command
    magic, cputype, _, _, ncmds = struct.unpack('<IiiII', exe[:20])
    off = 32
    has_sig = False
    for _ in range(ncmds):
        cmd, size = struct.unpack('<II', exe[off:off + 8])
        if cmd == 0x1d:  # LC_CODE_SIGNATURE
            has_sig = True
        off += size

    print('IPA: %s' % ipa)
    print('条目: %d' % entries)
    print('BundleID: %s' % info.get('CFBundleIdentifier'))
    print('版本: %s (%s)  MinimumOSVersion: %s'
          % (info.get('CFBundleShortVersionString'), info.get('CFBundleVersion'),
             info.get('MinimumOSVersion')))
    print('设备族: %s  必需能力: %s'
          % (info.get('UIDeviceFamily'), info.get('UIRequiredDeviceCapabilities')))
    print('主程序: magic=%#x cputype=%d（16777228=ARM64） load commands=%d'
          % (magic, cputype, ncmds))
    print('主程序带 LC_CODE_SIGNATURE: %s' % has_sig)
    print('_CodeSignature 条目: %d' % len(signed_entries))
    print('资源: lua=%d wav=%d atlas_png=%d'
          % (counts['lua'], counts['wav'], counts['atlas']))

    if info.get('CFBundleIdentifier') != BID:
        problems.append('BundleID 不是 %s' % BID)
    if cputype != 16777228:
        problems.append('主程序不是 arm64')
    if has_sig:
        print('提示：主程序带 LC_CODE_SIGNATURE（ad-hoc 签名），自洽性由 check_signature.py 负责')
    if counts['lua'] != 60 or counts['wav'] != 70:
        problems.append('资源数量不对：lua=%d wav=%d' % (counts['lua'], counts['wav']))

    if problems:
        for p in problems:
            print('!! ' + p)
        return 1
    print('校验通过：arm64 结构 + 资源齐全')
    return 0


if __name__ == '__main__':
    sys.exit(main())
