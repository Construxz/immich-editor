"""Animated before/after for the README (D-81): a divider wipes across each photo — original on
the left, our edit on the right — then the next one; one looping WebP.
  python tool/before_after.py out.webp original1.jpg edited1.png [original2 edited2 ...]
The originals must be cropped like the edits (same framing); sizes may differ."""

import math
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 840, 560          # canvas; each photo is fitted inside
FPS, SECONDS = 15, 3.2   # per photo: there and back
FONT = "fonts/GoogleSans/GoogleSans-Medium.ttf"


def fit(im):
    k = min(W / im.width, H / im.height)
    return im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)


def label(d, xy, text, font):
    x, y = xy
    box = d.textbbox((x, y), text, font=font)
    d.rounded_rectangle([box[0] - 10, box[1] - 6, box[2] + 10, box[3] + 6], 12, fill=(0, 0, 0, 150))
    d.text((x, y), text, font=font, fill="white")


def frames(before, after, font):
    b, a = fit(before.convert("RGB")), fit(after.convert("RGB"))
    a = a.resize(b.size, Image.LANCZOS)
    ox, oy = (W - b.width) // 2, (H - b.height) // 2
    n = round(FPS * SECONDS)
    for i in range(n):
        # eased 0.12 → 0.88 → 0.12 of the width
        t = 0.5 - 0.5 * math.cos(2 * math.pi * i / n)
        x = round(b.width * (0.12 + 0.76 * t))
        f = Image.new("RGB", (W, H), (32, 33, 36))
        img = a.copy()
        img.paste(b.crop((0, 0, x, b.height)), (0, 0))
        f.paste(img, (ox, oy))
        d = ImageDraw.Draw(f, "RGBA")
        d.rectangle([ox + x - 2, oy, ox + x + 1, oy + b.height], fill="white")
        cy = oy + b.height // 2
        d.ellipse([ox + x - 22, cy - 22, ox + x + 22, cy + 22], fill="white")
        d.polygon([(ox + x - 6, cy - 9), (ox + x - 15, cy), (ox + x - 6, cy + 9)], fill=(32, 33, 36))
        d.polygon([(ox + x + 6, cy - 9), (ox + x + 15, cy), (ox + x + 6, cy + 9)], fill=(32, 33, 36))
        label(d, (ox + 18, oy + b.height - 52), "Original", font)
        text = "Editor for Immich"
        tw = d.textlength(text, font=font)
        label(d, (ox + b.width - tw - 18, oy + b.height - 52), text, font)
        yield f


if __name__ == "__main__":
    out, paths = sys.argv[1], sys.argv[2:]
    font = ImageFont.truetype(FONT, 22)
    all_frames = []
    for before, after in zip(paths[::2], paths[1::2]):
        all_frames += list(frames(Image.open(before), Image.open(after), font))
    all_frames[0].save(out, save_all=True, append_images=all_frames[1:], duration=round(1000 / FPS),
                       loop=0, quality=72, method=6)
    print(out, len(all_frames), "frames")
