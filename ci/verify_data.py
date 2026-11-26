#!/usr/bin/env python3
"""构建前的数据自检：所有关卡对象都能找到贴图或碰撞数据，Lua 脚本齐全。

用法: verify_data.py <Resources 目录>
失败时打印明细并以非 0 退出。
"""
import json
import os
import sys


def main():
    res = sys.argv[1]
    frames = json.load(open(os.path.join(res, "atlas", "frames.json")))["sheets"]
    levels = json.load(open(os.path.join(res, "data", "levels.json")))
    edges = json.load(open(os.path.join(res, "data", "edges.json")))

    def sheet_of(layer, suite):
        if layer in ("Background", "Farground"):
            return "FargroundsS%d-hd" % suite
        if layer in ("Texture", "Foreground"):
            return "TextureS%d-hd" % suite
        if layer in ("Item", "DynamicObject"):
            return "DynamicObjectsLite-hd"
        return None

    def base_of(layer, seq):
        table = {"Background": "Background_%03d.png", "Farground": "Farground_%03d.png",
                 "Texture": "Texture_%03d.png", "Foreground": "Foreground_%03d.png",
                 "Item": "Item_%03d", "DynamicObject": "DynamicObject_%03d"}
        return table[layer] % seq

    def has_frame(sheet, base):
        names = frames[sheet]["frames"]
        if base in names:
            return True
        prefix = base[:-4] if base.endswith(".png") else base
        return any(k == prefix or k.startswith(prefix + "/") for k in names)

    missing = []
    objects = 0
    for key, level in levels.items():
        suite = level["suite"]
        for layer in level["layers"]:
            name = layer["name"]
            if name in ("StaticObject", "Area"):
                continue
            sheet = sheet_of(name, suite)
            if sheet is None:
                continue
            for obj in layer["objs"]:
                if name == "Background" and obj["seq"] == 1:
                    continue
                objects += 1
                if not has_frame(sheet, base_of(name, obj["seq"])):
                    missing.append((key, name, obj["seq"]))
        for layer in level["layers"]:
            if layer["name"] != "StaticObject":
                continue
            for obj in layer["objs"]:
                if str(obj["seq"]) not in edges:
                    missing.append((key, "edges", obj["seq"]))

    lua_dir = os.path.join(res, "data", "lua")
    scripts = sorted(f for f in os.listdir(lua_dir) if f.endswith(".lua"))
    if len(scripts) != 60:
        print("!! 关卡脚本数量 %d，应为 60" % len(scripts))
        return 1

    audio = os.listdir(os.path.join(res, "audio"))
    print("关卡 %d · 贴图对象 %d · 图集帧 %d · Lua %d · 音效 %d"
          % (len(levels), objects, sum(len(s["frames"]) for s in frames.values()), len(scripts), len(audio)))

    if missing:
        print("!! 缺失 %d 处（最多列 20 条）:" % len(missing))
        for item in missing[:20]:
            print("   ", item)
        return 1

    for sheet in frames:
        for page in frames[sheet]["pages"]:
            path = os.path.join(res, "atlas", page["image"])
            if not os.path.isfile(path):
                print("!! 缺图集页", path)
                return 1
    print("数据自检通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
