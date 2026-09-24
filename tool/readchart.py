"""Reads the test chart back (D-71): mean sRGB of the central 60 × 60 of every patch.
  python tool/readchart.py copy.png              → one line per patch: column row r g b
  python tool/readchart.py a.png b.png [c.png]   → per patch the values side by side
  python tool/readchart.py --distance ours.png google.png
      → mean |ours − google| over all patches, relative to Google's own change (the D-73 measure)
Copies of another size (a JPEG from Google Photos) are sampled at the same relative spots."""

import sys

import numpy as np
from PIL import Image

from testchart import CELL, H, W, patches


def read(path):
    """[(column, row, chart rgb, measured rgb)] for every patch."""
    a = np.asarray(Image.open(path).convert("RGB"), dtype=float)
    sy, sx = a.shape[0] / H, a.shape[1] / W
    out = []
    for c, r, rgb in patches():
        y0, x0 = (r * CELL + 20) * sy, (c * CELL + 20) * sx
        box = a[round(y0):round(y0 + 60 * sy), round(x0):round(x0 + 60 * sx)]
        out.append((c, r, rgb, box.reshape(-1, 3).mean(0)))
    return out


def distance(ours, google):
    """(relative, absolute in 8-bit levels): mean |ours − google| per patch and channel, and that
    relative to the mean |google − chart|."""
    o, g = (np.array([x[3] for x in read(p)]) for p in (ours, google))
    chart = np.array([x[2] for x in patches()], dtype=float)
    err = np.abs(o - g).mean()
    return err / np.abs(g - chart).mean(), err


if __name__ == "__main__":
    if sys.argv[1] == "--distance":
        rel, err = distance(sys.argv[2], sys.argv[3])
        print(f"{rel:.1%} ({err:.1f} levels)")
        sys.exit()
    rows = [read(p) for p in sys.argv[1:]]
    for i, (c, r, rgb, _) in enumerate(rows[0]):
        print(f"{c:2} {r:2} {rgb!s:16}", "  ".join(" ".join(f"{v:5.1f}" for v in x[i][3]) for x in rows))
