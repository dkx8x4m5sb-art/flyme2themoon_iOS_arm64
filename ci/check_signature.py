#!/usr/bin/env python3
"""校验 .app 的签名是否自洽（CodeDirectory 与 Mach-O / Info.plist / CodeResources 一致）。

CodeDirectory 里哈希数组的真实布局（Apple cs_blobs.h）：
  hashOffset 指向"第 0 个 code slot"；
  special slot 存在 hashOffset 之前，第 k 号 special slot 位于
  [hashOffset - k*hashSize, hashOffset - (k-1)*hashSize)。
  k=1 Info.plist，k=2 Requirements，k=3 CodeResources（ResourceDir）。

用法：python3 ci/check_signature.py <FlyMe2theMoon.app>
未签名时返回 2；签名存在但校验失败返回 1；全部一致返回 0。
"""
import hashlib
import os
import struct
import sys

SPECIAL_KIND = {1: 'Info.plist', 2: 'Requirements', 3: 'CodeResources',
                5: 'Entitlements', 6: 'DER Entitlements'}


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
        _, o = struct.unpack('>II', blob[12 + i * 8:20 + i * 8])
        if struct.unpack('>I', blob[o:o + 4])[0] == 0xfade0c02:
            cd = blob[o:]
            fields = {
                'length': struct.unpack('>I', cd[4:8])[0],
                'version': struct.unpack('>I', cd[8:12])[0],
                'flags': struct.unpack('>I', cd[12:16])[0],
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
    print('CodeDirectory: ident=%s version=%#x flags=%#x len=%d nSpecial=%d nCode=%d codeLimit=%d hashSize=%d'
          % (f['ident'].decode(errors='replace'), f['version'], f['flags'], f['length'],
             f['nSpecial'], f['nCode'], f['codeLimit'], f['hashSize']))

    page = (1 << f['pageSizeLog']) if f['pageSizeLog'] else 0
    ho, hs = f['hashOffset'], f['hashSize']
    ns, nc = f['nSpecial'], f['nCode']
    problems = []

    if ho < ns * hs:
        problems.append('special slot 区越界：hashOffset=%d < nSpecial*hashSize=%d' % (ho, ns * hs))
    if f['length'] < ho + nc * hs:
        problems.append('code slot 区越界：CD 长 %d < hashOffset+nCode*hashSize=%d'
                        % (f['length'], ho + nc * hs))

    bad = []
    for i in range(nc):
        start = i * page
        end = min(start + page, f['codeLimit'])
        digest = hashlib.sha256(binary[start:end]).digest()[:hs]
        if digest != cd[ho + i * hs:ho + (i + 1) * hs]:
            bad.append(i)
    print('分页哈希：%d/%d 不一致' % (len(bad), nc))
    if bad:
        print('前几个坏页：%s' % bad[:10])
        problems.append('分页哈希不一致')

    def slot(k):
        return cd[ho - k * hs:ho - (k - 1) * hs]

    print('special slots（共 %d 个）:' % ns)
    for k in range(1, ns + 1):
        b = slot(k)
        name = SPECIAL_KIND.get(k, 'slot-%d' % k)
        state = 'ZERO' if not any(b) else b[:8].hex() + '…'
        print('  slot %d (%s): %s' % (k, name, state))

    # Info.plist = special slot 1
    plist_bytes = open(os.path.join(app, 'Info.plist'), 'rb').read()
    plist_ok = hashlib.sha256(plist_bytes).digest()[:hs] == slot(1)
    print('Info.plist 槽：%s' % ('一致' if plist_ok else '不一致'))
    if not plist_ok:
        problems.append('Info.plist 槽不一致')

    # CodeResources = special slot 3
    res_ok = None
    cr_path = os.path.join(app, '_CodeSignature', 'CodeResources')
    if os.path.exists(cr_path) and ns >= 3:
        cr = open(cr_path, 'rb').read()
        res_ok = hashlib.sha256(cr).digest()[:hs] == slot(3)
        print('CodeResources 槽：%s（%d 字节）' % ('一致' if res_ok else '不一致', len(cr)))
        if not res_ok:
            problems.append('CodeResources 槽不一致')
    elif ns >= 3:
        print('CodeResources 槽：缺 _CodeSignature/CodeResources')
        res_ok = False
        problems.append('缺 _CodeSignature/CodeResources')

    cdhash = hashlib.sha256(cd[:f['length']]).hexdigest()[:40]
    print('cdhash(sha256) = %s' % cdhash)

    if f['flags'] & 0x2:
        print('flags: ad-hoc（无开发者证书）')

    if problems:
        print('!! 签名自洽性校验失败：%s' % '；'.join(problems))
        return 1
    print('签名自洽：分页哈希 %d/%d、Info.plist 槽、CodeResources 槽全部一致' % (nc, nc))
    return 0


if __name__ == '__main__':
    sys.exit(main())
