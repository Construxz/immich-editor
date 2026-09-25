"""App icon from the owner's artwork (D-80): Android adaptive icon (dark background, the artwork
as foreground inside the safe zone), legacy PNGs, the README tile and GitHub's social preview.
Run from the project root: python tool/make_icons.py docs/assets/icon-source.png
The artwork is made for a dark background (its center has a white glow)."""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

BACKGROUND = (32, 33, 36)  # also in res/values/ic_launcher_background.xml
RES = "android/app/src/main/res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def content(path):
    """The artwork cropped to its visible part, square."""
    im = Image.open(path).convert("RGBA")
    box = im.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    im = im.crop(box)
    side = max(im.size)
    square = Image.new("RGBA", (side, side))
    square.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return square


def placed(art, size, share, background=None, radius=0):
    """[art] centered on a [size] canvas, [share] of its width."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if background:
        ImageDraw.Draw(canvas).rounded_rectangle([0, 0, size - 1, size - 1], radius, fill=background + (255,))
    s = round(size * share)
    canvas.alpha_composite(art.resize((s, s), Image.LANCZOS), ((size - s) // 2, (size - s) // 2))
    return canvas


if __name__ == "__main__":
    art = content(sys.argv[1])
    for name, k in DENSITIES.items():
        folder = f"{RES}/mipmap-{name}"
        os.makedirs(folder, exist_ok=True)
        # Adaptive: 108 dp canvas, masks show the inner 72 dp, always the inner 66 dp circle.
        placed(art, round(108 * k), 0.62).save(f"{folder}/ic_launcher_foreground.png")
        # Legacy (48 dp), for launchers that ignore the adaptive icon.
        placed(art, round(48 * k), 0.78, BACKGROUND, round(48 * k * 0.22)).save(f"{folder}/ic_launcher.png")
    os.makedirs("docs/assets", exist_ok=True)
    placed(art, 512, 0.8, BACKGROUND, 112).save("docs/assets/icon.png")
    # GitHub social preview (1280 × 640): icon, name, slogan. Upload by hand in the repo settings.
    fonts = "fonts/GoogleSans"
    bold = next(f for f in os.listdir(fonts) if "Bold" in f and f.endswith(".ttf"))
    regular = next(f for f in os.listdir(fonts) if "Regular" in f and f.endswith(".ttf"))
    card = Image.new("RGBA", (1280, 640), BACKGROUND + (255,))
    card.alpha_composite(placed(art, 400, 0.95), (90, 120))
    d = ImageDraw.Draw(card)
    d.text((540, 245), "Editor for Immich", font=ImageFont.truetype(f"{fonts}/{bold}", 72), fill="white")
    d.text((542, 345), "Your photos. Your edits. Your server.",
           font=ImageFont.truetype(f"{fonts}/{regular}", 38), fill=(200, 200, 205))
    card.convert("RGB").save("docs/assets/social-preview.png")
    print("icons written")
