#!/usr/bin/env python3
"""校验 .app 的 ad-hoc 签名是否自洽（CodeDirectory 与 Mach-O / Info.plist / CodeResources 一致）。

用法：python3 ci/check_signature.py <FlyMe2theMoon.app>
未签名时返回 2；签名存在但校验失败返回 1；全部一致返回 0。
"""
import hashlib
import os
import plistlib
import struct
import sys


def parse_cd(binary):
    ncmds = struct.unpack('<I', binary[16:20])[0]
    off, dataoff, datasize = 32, None, None
    for _ in range(ncmds):
        cmd, size = struct.unpack('<II', binary[off:off + 8])
        if cmd == 0x1d:  # LC_CODE_SIGNATURE
            dataoff, datasize = struct.unpack('<II', binary[off + 8:off + 16])
        off += size
    if not dataoff:
        return None
    blob = binary[dataoff:dataoff + datasize]
    if struct.unpack('>I', blob[:4])[0] != 0xfade0cc0:
        raise ValueError('SuperBlob magic 不对')
    count = struct.unpack('>I', blob[8:12])[0]
    for i in range(count):
        slot, o = struct.unpack('>II', blob[12 + i * 8:20 + i * 8])
        if struct.unpack('>I', blob[o:o + 4])[0] == 0xfade0c02:
            cd = blob[o:]
            fields = {
                'version': struct.unpack('>I', cd[8:12])[0],
                'hashOffset': struct.unpack('>I', cd[16:20])[0],
                'identOffset': struct.unpack('>I', cd[20:24])[0],
                'nSpecial': struct.unpack('>I', cd[24:28])[0],
                'nCode': struct.unpack('>I', cd[28:32])[0],
                'codeLimit': struct.unpack('>I', cd[32:36])[0],
                'hashSize': cd[36],
                'hashType': cd[37],
                'pageSizeLog': cd[39],
            }
            fields['ident'] = cd[fields['identOffset']:fields['identOffset'] + 64].split(b'\x00')[0]
            return cd, fields
    return None


def main() -> int:
    app = sys.argv[1].rstrip('/')
    binary_path = os.path.join(app, os.path.basename(app)[:-4])
    binary = open(binary_path, 'rb').read()
    parsed = parse_cd(binary)
    if not parsed:
        print('未签名：主程序没有 LC_CODE_SIGNATURE')
        return 2
    cd, f = parsed
    print('CodeDirectory: ident=%s version=%#x nSpecial=%d nCode=%d codeLimit=%d hashSize=%d'
          % (f['ident'].decode(errors='replace'), f['version'], f['nSpecial'],
             f['nCode'], f['codeLimit'], f['hashSize']))

    page = 1 << f['pageSizeLog'] if f['pageSizeLog'] else 0
    ho, hs = f['hashOffset'], f['hashSize']
    bad = []
    for i in range(f['nCode']):
        start = i * page
        end = min(start + page, f['codeLimit'])
        digest = hashlib.sha256(binary[start:end]).digest()[:hs]
        stored = cd[ho + (f['nSpecial'] + i) * hs:ho + (f['nSpecial'] + i + 1) * hs]
        if digest != stored:
            bad.append(i)
    print('分页哈希：%d/%d 不一致' % (len(bad), f['nCode']))
    if bad:
        print('前几个坏页：%s' % bad[:10])

    plist_path = os.path.join(app, 'Info.plist')
    plist_bytes = open(plist_path, 'rb').read()
    slot0 = cd[ho:ho + hs]
    plist_ok = hashlib.sha256(plist_bytes).digest()[:hs] == slot0
    print('Info.plist 槽：%s' % ('一致' if plist_ok else '不一致'))

    res_ok = True
    cr_path = os.path.join(app, '_CodeSignature', 'CodeResources')
    if os.path.exists(cr_path) and f['nSpecial'] >= 3:
        cr = open(cr_path, 'rb').read()
        slot2 = cd[ho + 2 * hs:ho + 3 * hs]
        cand = hashlib.sha256(cr).digest()[:hs]
        if cand != slot2:
            cand = hashlib.sha1(cr).digest()[:hs]
        res_ok = cand == slot2
        print('CodeResources 槽：%s' % ('一致' if res_ok else '不一致'))

    if bad or not plist_ok or not res_ok:
        print('!! 签名自洽性校验失败')
        return 1
    print('签名自洽：分页哈希/Info.plist/CodeResources 全部一致')
    return 0


if __name__ == '__main__':
    sys.exit(main())
