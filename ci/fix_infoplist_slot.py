#!/usr/bin/env python3
"""把 Info.plist 的 SHA-256 补写进 CodeDirectory 的 special slot -1。

背景：codesign 给 iOS 扁平 bundle 做 ad-hoc 签名时，有时不把 Info.plist 绑定进
slot -1（签名结构里该槽为全零，`codesign -d` 显示 "Info.plist=not bound"），
第三方重签工具（全能签）预检会把它当成 “Info.plist 无效” 直接中止。
ad-hoc 签名没有 CMS 密文，slot -1 只是结构哈希，补齐后签名自洽性更好。

用法：python3 ci/fix_infoplist_slot.py <FlyMe2theMoon.app>
返回 0 表示已绑定或本来就一致；1 表示无法补齐（例如 slot 非零但不匹配）。
"""
import hashlib
import os
import struct
import sys


def locate_cd(data):
    ncmds = struct.unpack('<I', data[16:20])[0]
    off, dataoff, datasize = 32, None, None
    for _ in range(ncmds):
        cmd, size = struct.unpack('<II', data[off:off + 8])
        if cmd == 0x1d:  # LC_CODE_SIGNATURE
            dataoff, datasize = struct.unpack('<II', data[off + 8:off + 16])
        off += size
    if not dataoff:
        return None
    count = struct.unpack('>I', data[dataoff + 8:dataoff + 12])[0]
    for i in range(count):
        _, o = struct.unpack('>II', data[dataoff + 12 + i * 8:dataoff + 20 + i * 8])
        if struct.unpack('>I', data[dataoff + o:dataoff + o + 4])[0] == 0xfade0c02:
            return dataoff + o
    return None


def main() -> int:
    app = sys.argv[1].rstrip('/')
    exe = os.path.join(app, os.path.basename(app)[:-4])
    data = bytearray(open(exe, 'rb').read())

    cd_off = locate_cd(data)
    if cd_off is None:
        print('主程序没有 LC_CODE_SIGNATURE，跳过')
        return 1

    length = struct.unpack('>I', data[cd_off + 4:cd_off + 8])[0]
    hash_offset = struct.unpack('>I', data[cd_off + 16:cd_off + 20])[0]
    n_special = struct.unpack('>I', data[cd_off + 24:cd_off + 28])[0]
    n_code = struct.unpack('>I', data[cd_off + 28:cd_off + 32])[0]
    code_limit = struct.unpack('>I', data[cd_off + 32:cd_off + 36])[0]
    hash_size = data[cd_off + 36]
    page_log = data[cd_off + 39]
    page = (1 << page_log) if page_log else 0

    if n_special < 1:
        print('nSpecialSlots=%d，没有 Info.plist 槽' % n_special)
        return 1

    plist_path = os.path.join(app, 'Info.plist')
    h_info = hashlib.sha256(open(plist_path, 'rb').read()).digest()[:hash_size]
    slot_off = cd_off + hash_offset - hash_size
    current = bytes(data[slot_off:slot_off + hash_size])

    print('Info.plist sha256 = %s' % h_info.hex())
    print('slot -1 现值      = %s' % current.hex())

    if current == h_info:
        print('slot -1 已经绑定 Info.plist，无需修改')
        return 0
    if any(current):
        print('!! slot -1 非零且与当前 Info.plist 不一致：签名后 Info.plist 被改过')
        return 1

    data[slot_off:slot_off + hash_size] = h_info

    # 顺手复核分页哈希与 CodeResources 槽，避免补写掩盖更严重的问题
    bad = 0
    for i in range(n_code):
        s = i * page
        e = min(s + page, code_limit)
        if hashlib.sha256(bytes(data[s:e])).digest()[:hash_size] != \
                bytes(data[cd_off + hash_offset + i * hash_size:
                         cd_off + hash_offset + (i + 1) * hash_size]):
            bad += 1
    print('分页哈希复核：%d/%d 不一致' % (bad, n_code))
    if bad:
        print('!! 分页哈希不一致，补写 slot -1 也无法救回')
        return 1

    cr = os.path.join(app, '_CodeSignature', 'CodeResources')
    if os.path.exists(cr) and n_special >= 3:
        h_cr = hashlib.sha256(open(cr, 'rb').read()).digest()[:hash_size]
        cr_off = cd_off + hash_offset - 3 * hash_size
        if bytes(data[cr_off:cr_off + hash_size]) != h_cr:
            print('!! CodeResources 槽与文件不一致')
            return 1

    open(exe, 'wb').write(bytes(data))
    print('已写入 slot -1，CodeDirectory 长度不变（%d 字节）' % length)
    return 0


if __name__ == '__main__':
    sys.exit(main())
