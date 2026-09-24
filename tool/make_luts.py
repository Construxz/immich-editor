"""Generates the built-in filters as 3D LUTs (.cube, 17³) — own looks, not measured from others
(spec, *Filter*). Run from the project root: python tool/make_luts.py

A look must not change once shipped: recipes name it by ID. Change one → new ID (warm@2).
"""

import numpy as np

N = 17
OUT = "android/app/src/main/assets/luts"


def luma(c):
    return c @ np.array([0.2126, 0.7152, 0.0722])


def saturate(c, s):
    y = luma(c)[..., None]
    return y + (c - y) * s


def s_curve(c, k):  # k 0 … 1: blend toward smoothstep
    return c + k * (c * c * (3 - 2 * c) - c)


def lift(c, black, white=1.0):  # black level up, white level down
    return black + c * (white - black)


def mono(c):
    return np.repeat(luma(c)[..., None], 3, axis=-1)


def linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def balance(c, r, b):  # white balance in linear light
    return srgb(linear(c) * np.array([r, 1.0, b]))


def film(c):
    y = luma(c)[..., None]
    c = c + (1 - y) * np.array([-0.03, 0.01, 0.03]) + y * np.array([0.03, 0.0, -0.03])
    return lift(saturate(s_curve(c, 0.3), 0.9), 0.06, 0.95)


LOOKS = {
    "vivid@1": lambda c: s_curve(saturate(c, 1.35), 0.25),
    "warm@1": lambda c: balance(c, 1.10, 0.88),
    "cool@1": lambda c: balance(c, 0.90, 1.10),
    "film@1": film,
    "fade@1": lambda c: lift(saturate(c, 0.7), 0.12, 0.96),
    "bw@1": mono,
    "noir@1": lambda c: s_curve(s_curve(mono(c), 1.0), 0.5),
    "sepia@1": lambda c: lift(mono(c), 0.04, 0.97) * np.array([1.07, 0.98, 0.82]),
}


def grid():
    # .cube order: red varies fastest, then green, then blue
    b, g, r = np.meshgrid(*[np.linspace(0, 1, N)] * 3, indexing="ij")
    return np.stack([r, g, b], axis=-1).reshape(-1, 3)


if __name__ == "__main__":
    import os

    os.makedirs(OUT, exist_ok=True)
    for name, look in LOOKS.items():
        rows = np.clip(look(grid()), 0, 1)
        with open(f"{OUT}/{name}.cube", "w", newline="\n") as f:
            f.write(f"# Editor for Immich, {name} (tool/make_luts.py)\nLUT_3D_SIZE {N}\n")
            f.writelines(f"{r:.4f} {g:.4f} {b:.4f}\n" for r, g, b in rows)
    print(f"{len(LOOKS)} looks in {OUT}")
