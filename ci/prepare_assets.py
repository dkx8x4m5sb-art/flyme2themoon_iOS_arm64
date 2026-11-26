#!/usr/bin/env python3
"""从原版 FlyMe2theMoon.app 重建可用的运行资源。

做的事：
  1. 把 data/（关卡 JSON、Lua 脚本、教程回放）、audio/、art/、fonts/ 原样搬进 Resources。
  2. 读 atlas.json（cocos2d 的 9 元组：x,y,w,h,rotated,offX,offY,srcW,srcH），
     生成 Resources/atlas/frames.json。未旋转的帧直接引用原页矩形（像素零改动），
     旋转帧在页尾追加一张“补页”，把它们转正后放进去，运行时就不必处理旋转。
  3. 输出统计，方便 CI 断言素材完整。

用法: prepare_assets.py <解包后的 .app 目录> <输出 Resources 目录>
"""
import json
import os
import shutil
import sys

from PIL import Image

SHEETS_ORDER = [
    "CharActions-hd",
    "DynamicObjectsLite-hd",
    "FargroundsS1-hd",
    "FargroundsS2-hd",
    "FargroundsS3-hd",
    "FargroundsS4-hd",
    "TextureS1-hd",
    "TextureS2-hd",
    "TextureS3-hd",
    "TextureS4-hd",
]


def copy_tree(src, dst):
    if not os.path.isdir(src):
        return 0
    n = 0
    for root, _dirs, files in os.walk(src):
        rel = os.path.relpath(root, src)
        out = dst if rel == "." else os.path.join(dst, rel)
        os.makedirs(out, exist_ok=True)
        for f in files:
            shutil.copy2(os.path.join(root, f), os.path.join(out, f))
            n += 1
    return n


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    app = sys.argv[1]
    out = sys.argv[2]
    os.makedirs(os.path.join(out, "atlas"), exist_ok=True)

    copied = {}
    for name in ("data", "audio", "art", "fonts"):
        copied[name] = copy_tree(os.path.join(app, name), os.path.join(out, name))

    raw = json.load(open(os.path.join(app, "data", "atlas.json"), encoding="utf-8"))
    atlas_dir = os.path.join(app, "atlas")
    frames_path = os.path.join(out, "atlas", "frames.json")

    result = {"sheets": {}}
    total = 0
    rotated_total = 0

    for sheet in SHEETS_ORDER:
        if sheet not in raw:
            raise SystemExit("atlas.json 缺少图集: %s" % sheet)
        src_frames = raw[sheet]
        page_files = sorted(f for f in os.listdir(atlas_dir)
                            if f.startswith(sheet + ".") and f.endswith(".png"))
        if not page_files:
            raise SystemExit("找不到图集页: %s" % sheet)
        images = []
        pages = []
        for f in page_files:
            im = Image.open(os.path.join(atlas_dir, f)).convert("RGBA")
            shutil.copy2(os.path.join(atlas_dir, f), os.path.join(out, "atlas", f))
            images.append(im)
            pages.append({"image": f, "w": im.width, "h": im.height})

        frames = {}
        rotated = []
        for name, t in src_frames.items():
            x, y, w, h, rot = int(t[0]), int(t[1]), int(t[2]), int(t[3]), int(t[4])
            ox, oy = int(t[5]), int(t[6])
            sw, sh = int(t[7]), int(t[8])
            if w <= 0 or h <= 0:
                continue  # 空占位帧
            # 未旋转帧必须落在页内
            if not rot:
                if x + w > images[0].width or y + h > images[0].height:
                    raise SystemExit("帧越界 %s/%s" % (sheet, name))
                frames[name] = {"p": 0, "x": x, "y": y, "w": w, "h": h,
                                "ox": ox, "oy": oy, "sw": sw, "sh": sh}
            else:
                rotated.append((name, x, y, w, h, ox, oy, sw, sh))
        total += len(frames)
        rotated_total += len(rotated)

        if rotated:
            # 补页：把这些帧转正后紧凑排布
            tiles = []
            for item in rotated:
                name, x, y, w, h, ox, oy, sw, sh = item
                block = images[0].crop((x, y, x + h, y + w)).rotate(-90, expand=True)
                if block.size != (w, h):
                    raise SystemExit("旋转帧尺寸不符 %s/%s %s != %s" % (sheet, name, block.size, (w, h)))
                tiles.append((name, block, w, h, ox, oy, sw, sh))

            # 简单 shelf packing，页宽 1024，不够再开新页
            page_w = 1024
            margin = 1
            cx = cy = row_h = margin
            page_index = len(pages)
            canvas = Image.new("RGBA", (page_w, 1024), (0, 0, 0, 0))
            extra_pages = []
            for name, block, w, h, ox, oy, sw, sh in tiles:
                if cx + w + margin > page_w:
                    cx, cy, row_h = margin, cy + row_h + margin, 0
                if cy + h + margin > canvas.height:
                    extra_pages.append(canvas)
                    canvas = Image.new("RGBA", (page_w, 1024), (0, 0, 0, 0))
                    cx, cy, row_h = margin, margin, 0
                canvas.paste(block, (cx, cy))
                frames[name] = {"p": page_index + len(extra_pages), "x": cx, "y": cy,
                                "w": w, "h": h, "ox": ox, "oy": oy, "sw": sw, "sh": sh}
                cx += w + margin
                row_h = max(row_h, h)
            extra_pages.append(canvas)
            for i, page in enumerate(extra_pages):
                extra_name = "%s-extra%d.png" % (sheet, i)
                # 裁到实际用到的高度，省显存
                bbox = page.getbbox()
                height = 1024 if bbox is None else max(64, ((bbox[3] + 63) // 64) * 64)
                page.crop((0, 0, page.width, height)).save(os.path.join(out, "atlas", extra_name))
                pages.append({"image": extra_name, "w": page.width, "h": height})

        result["sheets"][sheet] = {"pages": pages, "frames": frames}
        print("%-22s 页 %d 帧 %d 旋转 %d" % (sheet, len(pages), len(frames), len(rotated)))

    json.dump(result, open(frames_path, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))

    levels = json.load(open(os.path.join(app, "data", "levels.json"), encoding="utf-8"))
    print("资源: data=%d audio=%d art=%d fonts=%d" % (copied["data"], copied["audio"], copied["art"], copied["fonts"]))
    print("关卡: %d  图集帧: %d（旋转 %d）" % (len(levels), total, rotated_total))

    required = ["data/levels.json", "data/atlas.json", "data/edges.json", "data/dialogs.json",
                "data/role.json", "data/score.json", "data/levelselect.json", "data/dependency.json",
                "atlas/frames.json"]
    for rel in required:
        if not os.path.isfile(os.path.join(out, rel)):
            raise SystemExit("缺少资源: " + rel)
    if total < 800:
        raise SystemExit("图集帧数量异常: %d" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
