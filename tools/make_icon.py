#!/usr/bin/env python3
"""不依赖 Pillow，纯标准库生成 1024x1024 App 图标 PNG。"""
import math, os, struct, zlib

W = H = 1024
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "ousic", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png")


def lerp(a, b, t):
    return a + (b - a) * t


def render():
    rows = []
    for y in range(H):
        row = []
        for x in range(W):
            t = (x + y) / (2 * W)
            r = int(lerp(8, 38, t))
            g = int(lerp(10, 52, t))
            b = int(lerp(24, 96, t))
            # 音波
            for i, (cr, cg, cb) in enumerate([(70, 210, 250), (160, 120, 255), (90, 235, 205)]):
                amp = 62 + i * 16
                if 140 <= x <= 884:
                    y0 = H / 2 + math.sin(x / 170.0 + i * 1.4) * amp * math.sin(x / 760.0 * math.pi)
                    if abs(y - y0) < 4:
                        k = 0.9
                        r = int(lerp(r, cr, k))
                        g = int(lerp(g, cg, k))
                        b = int(lerp(b, cb, k))
            # 同心圆
            dx, dy = x - W / 2, y - H / 2
            dist = math.hypot(dx, dy)
            for i in range(1, 7):
                ring = 320 + i * 9
                if abs(dist - ring) < 2.2:
                    k = 0.35 * (1 - i / 8)
                    r = int(lerp(r, 120, k))
                    g = int(lerp(g, 225, k))
                    b = int(lerp(b, 255, k))
            if 300 <= dist <= 340:
                r, g, b = 245, 250, 255
            if dist < 92:
                r, g, b = 250, 252, 255
            row.extend((r, g, b))
        rows.append(row)
    return rows


def write_png(path, rows):
    raw = b"".join(b"\x00" + bytes(row) for row in rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    header = struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) \
        + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


if __name__ == "__main__":
    write_png(OUT, render())
    print("icon ->", OUT, os.path.getsize(OUT), "bytes")
