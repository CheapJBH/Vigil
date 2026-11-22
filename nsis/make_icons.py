#!/usr/bin/env python3
"""生成 Vigil 安装包图标（installer.ico / uninstaller.ico）
风格：品牌蓝底圆角方块 + 白色几何 V，16px 下仍可辨识。
"""
import io
import os
import struct
from PIL import Image, ImageDraw

OUT = os.path.dirname(os.path.abspath(__file__))
SIZES = [16, 24, 32, 48, 64, 128, 256]
SS = 8  # 超采样

BLUE = (47, 111, 237, 255)     # #2f6fed 品牌蓝
WHITE = (255, 255, 255, 255)
DARK = (31, 35, 41, 255)       # #1f2329

# V 的多边形（0..1 归一化坐标）
V_POLY = [
    (0.22, 0.24), (0.38, 0.24), (0.50, 0.60), (0.62, 0.24), (0.78, 0.24),
    (0.575, 0.78), (0.425, 0.78),
]


def render(size, bg=BLUE, fg=WHITE, radius=0.18):
    W = size * SS
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, W - 1, W - 1], radius=int(W * radius), fill=bg)
    d.polygon([(x * W, y * W) for x, y in V_POLY], fill=fg)
    return img.resize((size, size), Image.LANCZOS)


def save_ico(path, bg=BLUE, fg=WHITE):
    imgs = [render(s, bg, fg) for s in SIZES]
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
    with open(path, "wb") as f:
        f.write(header + entries + blob)


def main():
    save_ico(os.path.join(OUT, "installer.ico"), BLUE, WHITE)
    # 卸载器：深灰底 + 白色 V，视觉上区分
    save_ico(os.path.join(OUT, "uninstaller.ico"), DARK, WHITE)

    # 预览
    prev = Image.new("RGBA", (32 + 48 + 64 + 256 + 60, 256), (245, 246, 248, 255))
    x = 10
    for s in (32, 48, 64, 256):
        im = render(s)
        prev.alpha_composite(im, (x, (256 - s) // 2))
        x += s + 10
    prev.save(os.path.join(OUT, "icon-preview.png"))

    for f in ("installer.ico", "uninstaller.ico"):
        p = os.path.join(OUT, f)
        im = Image.open(p)
        print(f"{f}: {os.path.getsize(p)} bytes sizes={sorted(im.info['sizes'])}")


if __name__ == "__main__":
    main()
