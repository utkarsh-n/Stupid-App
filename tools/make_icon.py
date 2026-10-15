#!/usr/bin/env python3
"""
Generates the app icon.

The mark is the hyperbolic taper curve itself — steep at the start, flattening as
it approaches but never quite touching zero, which is the actual shape of the
thing the app is for. Abstract enough to read as a signal, a tide, or a graph to
anyone glancing at the home screen, which is the point.
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os

SIZE = 1024

# Tidewater, matching Theme.swift.
DEEP = (12, 21, 38)
DEEP_LOW = (18, 38, 66)
TIDE = (88, 194, 181)
TIDE_GLOW = (140, 220, 208)
TIDE_DEEP = (52, 130, 122)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def background():
    img = Image.new("RGB", (SIZE, SIZE), DEEP)
    d = ImageDraw.Draw(img)
    # Vertical gradient, deep at top to a slightly lifted navy at the bottom.
    for y in range(SIZE):
        t = y / (SIZE - 1)
        d.line([(0, y), (SIZE, y)], fill=lerp(DEEP, DEEP_LOW, t))

    # A soft pool of light behind where the curve settles, so the flat tail has
    # somewhere to sit instead of dying into the corner.
    glow = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy, r = SIZE * 0.62, SIZE * 0.70, SIZE * 0.34
    for i in range(60, 0, -1):
        t = i / 60
        rr = r * t
        gd.ellipse(
            [cx - rr, cy - rr, cx + rr, cy + rr],
            fill=lerp((0, 0, 0), (16, 52, 60), 1 - t),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(SIZE * 0.06))
    return Image.blend(img, Image.blend(img, glow, 0.0), 0.0) if False else \
        Image.fromarray(_screen(img, glow))


def _screen(a, b):
    import numpy as np
    A = np.asarray(a).astype(float) / 255.0
    B = np.asarray(b).astype(float) / 255.0
    out = 1 - (1 - A) * (1 - B)
    return (out * 255).astype("uint8")


def curve_points(n=900):
    """Exponential decay across the icon's optical centre."""
    x0, x1 = SIZE * 0.18, SIZE * 0.81
    y_top, y_floor = SIZE * 0.25, SIZE * 0.715
    pts = []
    k = 3.1  # decay steepness
    for i in range(n):
        t = i / (n - 1)
        x = x0 + (x1 - x0) * t
        y = y_floor - (y_floor - y_top) * math.exp(-k * t)
        pts.append((x, y))
    return pts


def draw_curve(img):
    pts = curve_points()

    # Glow pass, drawn wide and blurred, then screened back over the ground.
    glow = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for (x, y) in pts:
        r = SIZE * 0.040
        gd.ellipse([x - r, y - r, x + r, y + r], fill=(20, 78, 74))
    glow = glow.filter(ImageFilter.GaussianBlur(SIZE * 0.035))
    img = Image.fromarray(_screen(img, glow))

    # The stroke itself: circles along the path give round caps and let the
    # colour travel from deep teal at the steep end to bright at the tail.
    d = ImageDraw.Draw(img)
    stroke = SIZE * 0.048
    for i, (x, y) in enumerate(pts):
        t = i / (len(pts) - 1)
        color = lerp(TIDE_DEEP, TIDE, min(1.0, t * 1.6))
        r = stroke / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)

    # Endpoint: where the taper is heading. Brighter, slightly larger, with its
    # own halo so the eye lands there rather than on the steep start.
    ex, ey = pts[-1]
    halo = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hr = SIZE * 0.075
    hd.ellipse([ex - hr, ey - hr, ex + hr, ey + hr], fill=(34, 104, 98))
    halo = halo.filter(ImageFilter.GaussianBlur(SIZE * 0.030))
    img = Image.fromarray(_screen(img, halo))

    d = ImageDraw.Draw(img)
    dr = SIZE * 0.043
    d.ellipse([ex - dr, ey - dr, ex + dr, ey + dr], fill=TIDE_GLOW)
    return img


def main():
    img = background()
    img = draw_curve(img)
    img = img.filter(ImageFilter.SMOOTH)

    out_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "StupidApp", "Assets.xcassets", "AppIcon.appiconset",
    )
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "icon-1024.png")
    img.save(path, "PNG")
    print("wrote", path)


if __name__ == "__main__":
    main()
