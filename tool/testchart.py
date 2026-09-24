"""Test chart for calibrating the adjustments against Google Photos (D-71): every patch has a
known sRGB value, so a copy edited elsewhere shows per patch what the adjustment did.
Run from the project root: python tool/testchart.py  → testchart.png (1200 × 1600)
Whoever reads the copies back samples the same grid (CELL, patches()): change both together."""

import colorsys

from PIL import Image, ImageDraw

W, H = 1200, 1600
CELL = 100  # patches are 100 × 100; the reader samples their central 60 × 60


def patches():
    """(column, row, (r, g, b)) — 12 columns × 16 rows."""
    out = []
    # Rows 0–1: gray ramp, 24 steps from black to white.
    for i in range(24):
        v = round(i * 255 / 23)
        out.append((i % 12, i // 12, (v, v, v)))
    # Rows 2–7: 12 hues × 3 saturations × 2 lightnesses.
    row = 2
    for light in (0.35, 0.6):
        for sat in (1.0, 0.6, 0.3):
            for h in range(12):
                r, g, b = colorsys.hls_to_rgb(h / 12, light, sat)
                out.append((h, row, (round(r * 255), round(g * 255), round(b * 255))))
            row += 1
    # Row 8: skin tones, light to dark.
    skin = [(255, 224, 196), (241, 194, 167), (224, 172, 138), (198, 134, 103), (161, 102, 72),
            (120, 75, 53), (92, 58, 42), (255, 205, 178), (234, 185, 156), (208, 150, 118),
            (174, 120, 90), (140, 90, 66)]
    out += [(i, 8, c) for i, c in enumerate(skin)]
    # Rows 9–10: dark and bright neutrals in fine steps (shadows, highlights).
    for i in range(12):
        v = round(i * 64 / 11)
        out.append((i, 9, (v, v, v)))
        v = round(191 + i * 64 / 11)
        out.append((i, 10, (v, v, v)))
    return out


if __name__ == "__main__":
    im = Image.new("RGB", (W, H), (128, 128, 128))
    d = ImageDraw.Draw(im)
    for c, r, rgb in patches():
        d.rectangle([c * CELL, r * CELL, c * CELL + CELL - 1, r * CELL + CELL - 1], fill=rgb)
    # Rows 11–15: mid gray (vignette and sharpness show on it) with a fine black/white edge.
    d.rectangle([0, 1100, W - 1, H - 1], fill=(128, 128, 128))
    for x in range(0, W, 40):
        d.rectangle([x, 1300, x + 19, 1399], fill=(0, 0, 0))
        d.rectangle([x + 20, 1300, x + 39, 1399], fill=(255, 255, 255))
    im.save("testchart.png")
    print("testchart.png", len(patches()), "patches")
