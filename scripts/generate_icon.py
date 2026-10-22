#!/usr/bin/env python3
"""Draws the original Pocket Outpost Tactics app icon (1024x1024, no alpha) with Pillow.

Usage: python3 scripts/generate_icon.py PocketOutpostTactics/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 4  # supersampling
W = 1024 * S

INK = (38, 50, 59)
CREAM = (255, 242, 219)
COPPER = (213, 139, 86)
GOLD = (243, 200, 107)
FOREST = (99, 135, 106)
SLATE = (97, 124, 152)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main(out):
    img = Image.new("RGB", (W, W), INK)
    d = ImageDraw.Draw(img)

    # Dusk sky gradient
    top, bottom = (46, 74, 68), (28, 38, 48)
    for y in range(W):
        d.line([(0, y), (W, y)], fill=lerp(top, bottom, y / W))

    # Stars
    for i in range(26):
        x = (i * 7919) % W
        y = (i * 104729) % int(W * 0.42)
        r = (2 + i % 3) * S
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255))

    # Back pines
    def pine(cx, base, h, color):
        for k, wf in enumerate([0.55, 0.42, 0.3]):
            y0 = base - k * h * 0.28
            d.polygon([(cx - h * wf, y0), (cx, y0 - h * 0.5), (cx + h * wf, y0)], fill=color, outline=INK, width=6 * S)

    for i, cx in enumerate([0.08, 0.2, 0.82, 0.94]):
        pine(cx * W, W * 0.66, W * 0.3 * (0.9 + (i % 2) * 0.15), (47, 85, 60))

    # Island (rounded diamond)
    cx, cy = W / 2, W * 0.72
    rx, ry = W * 0.47, W * 0.2
    earth = [(cx + rx * math.cos(a) * 1.0, cy + 90 * S + ry * math.sin(a)) for a in [i / 60 * 2 * math.pi for i in range(60)]]
    d.polygon(earth, fill=(107, 75, 51), outline=INK)
    grass = [(cx + rx * math.cos(a), cy + ry * math.sin(a)) for a in [i / 60 * 2 * math.pi for i in range(60)]]
    d.polygon(grass, fill=(110, 154, 94), outline=INK)
    d.line(grass + [grass[0]], fill=INK, width=10 * S)

    # Campfire glow
    glow = Image.new("RGB", (W, W), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gx, gy = W * 0.7, W * 0.74
    gd.ellipse([gx - 160 * S, gy - 90 * S, gx + 160 * S, gy + 90 * S], fill=(255, 170, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(60 * S))
    img = Image.blend(img, Image.composite(glow, img, glow.convert("L")), 0.45)
    d = ImageDraw.Draw(img)

    # Watchtower
    tx, base = W * 0.46, W * 0.74
    th = W * 0.34
    top_y = base - th
    lw = 22 * S
    for x0, x1 in [(tx - 150 * S, tx - 95 * S), (tx + 150 * S, tx + 95 * S)]:
        d.line([(x0, base), (x1, top_y)], fill=INK, width=lw + 10 * S)
        d.line([(x0, base), (x1, top_y)], fill=(176, 126, 74), width=lw)
    d.line([(tx - 135 * S, base - 40 * S), (tx + 100 * S, top_y + 70 * S)], fill=(122, 82, 51), width=14 * S)
    d.line([(tx + 135 * S, base - 40 * S), (tx - 100 * S, top_y + 70 * S)], fill=(122, 82, 51), width=14 * S)
    d.rounded_rectangle([tx - 150 * S, top_y - 70 * S, tx + 150 * S, top_y + 10 * S], radius=12 * S, fill=(190, 140, 84), outline=INK, width=8 * S)
    for px in (tx - 130 * S, tx + 130 * S):
        d.line([(px, top_y - 70 * S), (px, top_y - 150 * S)], fill=INK, width=14 * S)
    d.polygon([(tx - 190 * S, top_y - 140 * S), (tx, top_y - 260 * S), (tx + 190 * S, top_y - 140 * S)], fill=COPPER, outline=INK, width=10 * S)
    # Beacon
    d.ellipse([tx - 40 * S, top_y - 130 * S, tx + 40 * S, top_y - 60 * S], fill=GOLD, outline=INK, width=6 * S)
    # Banner
    fx, fy = tx, top_y - 260 * S
    d.line([(fx, fy), (fx, fy - 90 * S)], fill=INK, width=10 * S)
    d.polygon([(fx, fy - 90 * S), (fx + 110 * S, fy - 70 * S), (fx, fy - 45 * S)], fill=GOLD, outline=INK, width=6 * S)

    # Campfire
    for i in range(7):
        a = i / 7 * 2 * math.pi
        sx, sy = gx + math.cos(a) * 55 * S, gy + math.sin(a) * 22 * S
        d.ellipse([sx - 16 * S, sy - 11 * S, sx + 16 * S, sy + 11 * S], fill=(154, 149, 141), outline=INK, width=4 * S)
    d.polygon([(gx - 40 * S, gy), (gx, gy - 120 * S), (gx + 40 * S, gy)], fill=(255, 150, 60), outline=INK, width=5 * S)
    d.polygon([(gx - 18 * S, gy - 4 * S), (gx, gy - 70 * S), (gx + 18 * S, gy - 4 * S)], fill=(255, 238, 170))

    # Shield (Guardian emblem) in front
    sx, sy = W * 0.27, W * 0.78
    shield = [(sx - 120 * S, sy - 150 * S), (sx + 120 * S, sy - 150 * S), (sx + 110 * S, sy), (sx, sy + 120 * S), (sx - 110 * S, sy)]
    d.polygon(shield, fill=SLATE, outline=INK, width=12 * S)
    d.polygon([(sx, sy - 110 * S), (sx + 55 * S, sy - 20 * S), (sx, sy + 70 * S), (sx - 55 * S, sy - 20 * S)], fill=GOLD, outline=INK, width=6 * S)

    img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(out, "PNG")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "AppIcon-1024.png")
