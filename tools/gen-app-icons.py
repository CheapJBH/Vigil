#!/usr/bin/env python3
"""生成 Vigil 应用图标（教师端 / 学生端 / 配置器）
统一几何 V 造型，用背景色区分角色。
"""
import io
import os
import struct
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SIZES = [16, 24, 32, 48, 64, 128, 256]
SS = 8

BLUE = (47, 111, 237, 255)    # #2f6fed 教师端 / 配置器
DARK = (31, 35, 41, 255)      # #1f2329 学生端
GREEN = (22, 163, 74, 255)    # 备用

V_POLY = [
    (0.22, 0.24), (0.38, 0.24), (0.50, 0.60), (0.62, 0.24), (0.78, 0.24),
    (0.575, 0.78), (0.425, 0.78),
]


def render(size, bg, fg=(255, 255, 255, 255), radius=0.18):
    W = size * SS
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, W - 1, W - 1], radius=int(W * radius), fill=bg)
    d.polygon([(x * W, y * W) for x, y in V_POLY], fill=fg)
    return img.resize((size, size), Image.LANCZOS)


def write_ico(path, bg):
    imgs = [render(s, bg) for s in SIZES]
    pngs = []
    for im in imgs:
        buf = io.BytesIO()
        im.save(buf, format="PNG", optimize=True)
        pngs.append(buf.getvalue())

    n = len(imgs)
    header = struct.pack("<HHH", 0, 1, n)
    offset = 6 + 16 * n
    entries = b""
    blob = b""
    for im, png in zip(imgs, pngs):
        w = 0 if im.width >= 256 else im.width
        h = 0 if im.height >= 256 else im.height
        entries += struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(png), offset)
        offset += len(png)
        blob += png
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(header + entries + blob)
    return os.path.getsize(path)


def write_png(path, size, bg):
    im = render(size, bg)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, format="PNG", optimize=True)
    return os.path.getsize(path)


def main():
    targets = [
        ("master/data/vigil-master.ico", BLUE),
        ("configurator/data/vigil-configurator.ico", BLUE),
        ("worker/data/vigil-worker.ico", DARK),
        ("service/data/vigil-service.ico", DARK),
    ]
    for rel, bg in targets:
        p = os.path.join(ROOT, rel)
        if os.path.exists(p):
            bak = p + ".bak-veyon"
            if not os.path.exists(bak):
                os.rename(p, bak)
        size = write_ico(p, bg)
        print(f"{rel:52s} {size:>7d} B")

    for rel, bg in (("master/data/vigil-master.png", BLUE),
                    ("configurator/data/vigil-configurator.png", BLUE),
                    ("worker/data/vigil-worker.png", DARK)):
        p = os.path.join(ROOT, rel)
        print(f"{rel:52s} {write_png(p, 48, bg):>7d} B")


if __name__ == "__main__":
    main()
