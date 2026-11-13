"""Draws the small toppings in code (owner request: every item spread
evenly and in proportion, not in piles). Each piece is a loose sprinkle of
single bits with room between them, so the pieces, spread evenly over the
product, read as one even scattering:

- corn: a few kernels;
- ground beef: crumbles;
- tuna: flakes;
- capers: two or three capers;
- oregano: a dusting of dried flakes;
- parsley: chopped bits.

The colours come from the photos (assets_src/pizza/ingredients/
ing_<id>_01.webp, kept as the reference). Lighting is all round (no light
direction, no offset shadow), because the canvas turns every piece at random.

Usage (from the repo root): python tools/process_bits_assets.py [id ...]
Writes assets_src/pizza/ingredients/ing_<id>_g01..g06.webp (224 px, <= 150 KB).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

from process_cheese_assets import MAX, N, PIECE, Layer, noise, smooth, spots

VARIANTS = 6

# id: (bits per piece (min, max), spread radius, gap between bit centres,
#      bit radius (min, max), all of the piece box)
BITS = {
    'corn': ((3, 4), 0.27, 0.27, (0.1, 0.115)),
    'ground_beef': ((6, 8), 0.31, 0.19, (0.07, 0.1)),
    'tuna': ((4, 5), 0.28, 0.25, (0.095, 0.125)),
    'capers': ((2, 3), 0.24, 0.3, (0.1, 0.12)),
    'oregano': ((30, 40), 0.42, 0.055, (0.012, 0.024)),
    'parsley': ((22, 30), 0.4, 0.07, (0.016, 0.03)),
}


def place(layer, centre, size, local, colour, texture, *, gloss=0.0,
          contrast=0.25, tint=None):
    """Draws one bit around [centre] within [size] (pixels): [local] maps the
    box's (u, v) coordinates (relative to the centre) to (inside distance r,
    height h); r <= 1 is inside."""
    x0, y0 = (int(max(0, c - size)) for c in centre)
    x1, y1 = (int(min(N, c + size + 1)) for c in centre)
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    r, h = local(xx - centre[0], yy - centre[1], x0, y0)
    cover = np.zeros((N, N), np.float32)
    height = np.zeros((N, N), np.float32)
    # Soft edge over about a pixel of the final size.
    cover[y0:y1, x0:x1] = smooth((1 - r) / 0.06)
    height[y0:y1, x0:x1] = h
    layer.add(cover, height, colour, gloss, texture, contrast)
    if tint is not None:
        # A second colour inside the bit, e.g. darker crumbs or veins.
        t, amount = tint
        m = np.zeros((N, N), np.float32)
        m[y0:y1, x0:x1] = amount(xx, yy, x0, y0) * cover[y0:y1, x0:x1]
        col = np.asarray(t, np.float32)[None, None, :]
        layer.rgb = layer.rgb * (1 - m[..., None]) + col * m[..., None]


def lobed(rng, lobes):
    """A ragged outline: 1 plus a few random waves around the bit."""
    waves = [(rng.uniform(0.4, 1) * lobes / k, k, rng.uniform(0, 6.28))
             for k in range(2, 8)]
    return lambda a: 1 + sum(w * np.sin(a * k + p) for w, k, p in waves)


def kernel(layer, rng, centre, rad, texture):
    """A corn kernel: a rounded wedge, wider at its crown, glossy."""
    ang = rng.uniform(0, math.pi * 2)
    ca, sa = math.cos(ang), math.sin(ang)
    edge = lobed(rng, 0.03)

    def local(dx, dy, x0, y0):
        u = (dx * ca + dy * sa) / (rad * 1.12)
        v = (-dx * sa + dy * ca) / rad
        v = v / (1 - 0.2 * u)  # Narrower towards its root.
        r = (np.abs(u) ** 2.6 + np.abs(v) ** 2.6) ** (1 / 2.6)
        r = r / edge(np.arctan2(v, u))
        return r, smooth((1 - r) / 0.7)

    def crown(xx, yy, x0, y0):
        # The wide end is paler (the kernel's crown).
        u = ((xx - centre[0]) * ca + (yy - centre[1]) * sa) / (rad * 1.12)
        return 0.55 * smooth((-u - 0.15) / 0.7)

    shade = rng.uniform(-10, 8)
    colour = (250, 204 + shade, 44 + shade)
    place(layer, centre, rad * 1.5, local, colour, texture, gloss=0.08,
          contrast=0.18, tint=((252, 232, 150), crown))


def crumble(layer, rng, centre, rad, texture, colour, *, lobes, flat,
            contrast, gloss=0.0, bumps=None, tint=None, stretch=1.0):
    """An irregular lump (meat crumble, caper, herb flake)."""
    ang = rng.uniform(0, math.pi * 2)
    ca, sa = math.cos(ang), math.sin(ang)
    edge = lobed(rng, lobes)
    field = bumps

    def local(dx, dy, x0, y0):
        u = (dx * ca + dy * sa) / (rad * stretch)
        v = (-dx * sa + dy * ca) / rad
        r = np.hypot(u, v) / edge(np.arctan2(v, u))
        if field is not None:
            f = field[y0:y0 + dx.shape[0], x0:x0 + dx.shape[1]]
            r = r * (1 + 0.16 * (f - 0.5))
        h = smooth((1 - r) / flat)
        if field is not None:
            h = h * (0.8 + 0.4 * field[y0:y0 + dx.shape[0], x0:x0 + dx.shape[1]])
        return r, np.clip(h, 0, 1)

    place(layer, centre, rad * max(stretch, 1) * 1.6, local, colour, texture,
          gloss=gloss, contrast=contrast, tint=tint)


def piece(item: str, v: int) -> Image.Image:
    (lo, hi), spread, gap, (rmin, rmax) = BITS[item]
    rng = np.random.default_rng(sum(map(ord, item)) * 131 + v)
    texture = noise(17 + v, 120)
    layer = Layer()
    centres = spots(rng, int(rng.integers(lo, hi + 1)), spread, gap)
    for c in centres:
        rad = rng.uniform(rmin, rmax) * N
        if item == 'corn':
            kernel(layer, rng, c, rad, texture)
        elif item == 'ground_beef':
            bumps = noise(int(rng.integers(1 << 30)), 150)
            k = rng.uniform(-14, 14)
            crumble(layer, rng, c, rad, texture, (112 + k, 70 + k * 0.6, 48 + k * 0.4),
                    lobes=0.32, flat=0.55, contrast=0.55, bumps=bumps,
                    tint=((58, 30, 18), lambda xx, yy, x0, y0, b=bumps:
                          0.75 * smooth((b[yy.astype(int), xx.astype(int)] - 0.58) / 0.12)))
        elif item == 'tuna':
            stripes = noise(int(rng.integers(1 << 30)), 40)
            k = rng.uniform(-10, 10)
            crumble(layer, rng, c, rad, texture, (200 + k * 0.5, 150 + k, 112 + k),
                    lobes=0.22, flat=0.6, contrast=0.3, stretch=1.45,
                    tint=((160, 104, 70), lambda xx, yy, x0, y0, s=stripes:
                          0.5 * smooth((np.sin((xx + yy) * 0.35 + 6 * s[yy.astype(int), xx.astype(int)]) - 0.55) / 0.3)))
        elif item == 'capers':
            wrinkles = noise(int(rng.integers(1 << 30)), 90)
            crumble(layer, rng, c, rad, texture, (128, 120, 54),
                    lobes=0.06, flat=0.9, contrast=0.5, gloss=0.18, bumps=wrinkles,
                    tint=((78, 72, 26), lambda xx, yy, x0, y0, w=wrinkles:
                          0.55 * smooth((w[yy.astype(int), xx.astype(int)] - 0.62) / 0.1)))
        elif item == 'oregano':
            k = rng.uniform(0, 1)
            colour = tuple(np.array((96, 92, 38)) * (1 - k) + np.array((150, 128, 70)) * k)
            crumble(layer, rng, c, rad, texture, colour, lobes=0.45, flat=0.9,
                    contrast=0.12, stretch=rng.uniform(1, 1.7))
        elif item == 'parsley':
            k = rng.uniform(0, 1)
            colour = tuple(np.array((44, 104, 22)) * (1 - k) + np.array((88, 150, 40)) * k)
            crumble(layer, rng, c, rad, texture, colour, lobes=0.5, flat=0.8,
                    contrast=0.2, stretch=rng.uniform(1, 1.6))
    # A soft shadow all round, under the bits.
    shadow = Image.fromarray((layer.alpha * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(N * 0.01))
    sa = np.asarray(shadow, np.float32) / 255 * 0.3
    alpha = layer.alpha + sa * (1 - layer.alpha)

    # Reduce with premultiplied colour (the shadow is black), so edges keep
    # their colour.
    def down(channel):
        img = Image.fromarray(channel.astype(np.float32), 'F')
        return np.asarray(img.resize((PIECE, PIECE), Image.LANCZOS), np.float32)

    a = np.clip(down(alpha), 0, 1)
    rgb = np.stack([down(layer.rgb[..., i]) for i in range(3)], -1)
    rgb = rgb / np.maximum(a, 1e-4)[..., None]
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert('RGBA')
    img.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
    return img


def save(img: Image.Image, path: str) -> None:
    q = 92
    while True:
        img.save(path, 'WEBP', quality=q, method=6)
        if os.path.getsize(path) <= MAX or q <= 50:
            break
        q -= 6
    print(f'{path}: {os.path.getsize(path) // 1024} KB')


def main() -> None:
    out = 'assets_src/pizza/ingredients'
    for item in sys.argv[1:] or BITS:
        for v in range(VARIANTS):
            save(piece(item, v), f'{out}/ing_{item}_g{v + 1:02d}.webp')


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    main()
