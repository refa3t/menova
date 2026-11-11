"""Draws the sauce icons in code: the tile of each sauce in the builder (the
sauce itself is poured in code on the product, as a liquid). A small white
dip cup filled with the sauce, glossy, with its herbs or seeds if any.

Colours come from the sauce tables (SAUCES in tools/build_pizza_catalog.py,
SWEET_SAUCES in tools/build_crepe_catalog.py), the single source.

Usage (from the repo root): python tools/process_sauce_assets.py
Writes assets_src/pizza/ingredients/ing_<id>_cup.webp (savoury sauces) and
assets_src/crepe/ingredients/ing_<id>_cup.webp (sweet sauces), 200 px.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_crepe_catalog import SWEET_SAUCES  # noqa: E402
from build_pizza_catalog import SAUCES  # noqa: E402

SIZE = 200
SS = 4
N = SIZE * SS
MAX = 150 * 1024

# Bits in the sauce: colour, count, radius (of the icon).
BITS = {
    'ranch_sauce': ((74, 112, 52), 30, 0.011),
    'pesto_sauce': ((38, 66, 22), 46, 0.013),
    'hot_sauce': ((126, 24, 12), 26, 0.01),
    'honey_mustard': ((156, 104, 24), 34, 0.008),
    'strawberry_sauce': ((244, 206, 130), 20, 0.007),
    'pistachio_sauce': ((88, 116, 40), 28, 0.011),
}


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def icon(sauce: str, argb: int) -> Image.Image:
    colour = np.array([(argb >> 16) & 255, (argb >> 8) & 255, argb & 255],
                      np.float32)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / N
    cx, cy = 0.5, 0.47
    dx, dy = xx - cx, yy - cy
    r = np.hypot(dx, dy)
    theta = np.arctan2(dy, dx)
    cup_r, well_r = 0.42, 0.335
    light = 1 + 0.07 * ((0.5 - xx) + (0.5 - yy))

    # The cup: white ceramic, its rim rounded.
    rim = np.clip((r - well_r) / (cup_r - well_r), 0, 1)
    ceramic = np.array([247, 245, 239], np.float32)
    cup_shade = (0.84 + 0.16 * np.sin(math.pi * rim)) * light
    rgb = ceramic * cup_shade[..., None]

    # The sauce in it: shaded at the wall (more under the top edge), a slow
    # swirl, a gloss at the top left.
    edge = smooth((well_r - r) / 0.07)
    top = np.clip(-dy / well_r, 0, 1)
    shade = (0.8 + 0.2 * edge) * (1 - 0.1 * top * (1 - edge * 0.5)) * light
    shade = shade * (1 + 0.05 * np.sin(theta + r / well_r * 9))
    liquid = colour * shade[..., None]
    gx, gy = dx + 0.09, dy + 0.12
    a = math.radians(-28)
    u = gx * math.cos(a) - gy * math.sin(a)
    v = gx * math.sin(a) + gy * math.cos(a)
    gloss = np.exp(-((u / 0.11) ** 2 + (v / 0.035) ** 2)) * 0.55
    gloss += np.exp(-(((dx - 0.12) / 0.025) ** 2 + ((dy + 0.02) / 0.02) ** 2)) * 0.35
    liquid = liquid + (255 - liquid) * gloss[..., None]
    if bits := BITS.get(sauce):
        col, count, size = bits
        rng = np.random.default_rng(sum(map(ord, sauce)))
        for _ in range(count):
            rr = well_r * 0.88 * math.sqrt(rng.random())
            t = rng.random() * 2 * math.pi
            bx, by = cx + rr * math.cos(t), cy + rr * math.sin(t)
            s = size * rng.uniform(0.7, 1.3)
            d = np.hypot((xx - bx) / s, (yy - by) / (s * rng.uniform(0.5, 1)))
            m = smooth((1 - d) / 0.3)[..., None]
            liquid = liquid * (1 - m) + np.array(col, np.float32) * m
    inside = smooth((well_r - r) * N / 2)[..., None]
    rgb = rgb * (1 - inside) + liquid * inside

    cover = smooth((cup_r - r) * N / 2)
    # A soft shadow under the cup.
    shadow = Image.fromarray((cover * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(N * 0.025))
    shadow = np.asarray(shadow, np.float32) / 255
    shadow = np.roll(shadow, (int(N * 0.03), int(N * 0.012)), axis=(0, 1)) * 0.35
    alpha = cover + shadow * (1 - cover)
    prem = rgb * cover[..., None]

    def down(channel):
        img = Image.fromarray(channel.astype(np.float32), 'F')
        return np.asarray(img.resize((SIZE, SIZE), Image.LANCZOS), np.float32)

    a = np.clip(down(alpha), 0, 1)
    out = np.stack([down(prem[..., i]) for i in range(3)], -1)
    out = out / np.maximum(a, 1e-4)[..., None]
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).convert('RGBA')
    img.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
    return img



def save(img: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    q = 92
    while True:
        img.save(path, 'WEBP', quality=q, method=6)
        if os.path.getsize(path) <= MAX or q <= 50:
            break
        q -= 6
    print(f'{path}: {os.path.getsize(path) // 1024} KB')


def main() -> None:
    for folder, table in (('pizza', SAUCES), ('crepe', SWEET_SAUCES)):
        for key, *_, argb in table:
            save(icon(key, argb),
                 f'assets_src/{folder}/ingredients/ing_{key}_cup.webp')


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    main()
