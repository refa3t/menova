"""Draws the tortilla wrap assets in code (owner request: the tortilla
sandwich now, with its images; no photos yet), like the crepe's.

- Bases (1024 px, transparent, <= 500 KB): a thin flour tortilla, raw (as it
  comes, a few pale toast spots) and lightly toasted (golden, more and
  darker blistered spots).
- Its outside (assets_src/animation/tortilla_back.webp): the side that lay
  on the griddle, the outside of the rolled wrap (Roll step).
- New ingredients (224 px, 3 variants each, <= 150 KB): loose single bits,
  so pieces spread evenly read as one even filling (like
  tools/process_bits_assets.py): lettuce, pickles, fries, chicken shawarma,
  beef shawarma, crispy chicken.

Real photos can replace any file later under the same name.

Usage (from the repo root): python tools/process_tortilla_assets.py
Writes:
    assets_src/tortilla/bases/base_tortilla_raw.webp
    assets_src/tortilla/bases/base_tortilla_cooked.webp
    assets_src/animation/tortilla_back.webp
    assets_src/tortilla/ingredients/ing_<id>_01..03.webp
"""
import math
import os

import numpy as np
from PIL import Image, ImageFilter

import process_cheese_assets as cheese
from process_bits_assets import crumble, place
from process_cheese_assets import N, PIECE, Layer, downscale, noise, smooth, spots
from process_cheese_assets import save as save_piece
from process_crepe_assets import BASE, BASE_MAX, disc_mask
from process_crepe_assets import noise as base_noise
from process_crepe_assets import save as save_base

VARIANTS = 3


# ---- The tortilla ----------------------------------------------------------

def tortilla(seed: int, toast: float, back=False) -> Image.Image:
    """A flour tortilla: pale cream, thin, with round blistered toast spots
    (brown blotches where it bubbled). toast 0 = as it comes, 1 = toasted."""
    alpha, r = disc_mask(BASE, seed, wobble=0.008, radius=0.95)
    tone = base_noise(BASE, seed, ((6, 1.0), (20, 0.5), (60, 0.25)))
    raw = np.array([240, 228, 197], np.float32)
    gold = np.array([236, 211, 160], np.float32)
    rgb = np.broadcast_to(raw * (1 - toast) + gold * toast, (BASE, BASE, 3)).copy()
    rgb *= (0.95 + 0.08 * tone)[..., None]
    # Flour dust: fine pale speckles.
    dust = base_noise(BASE, seed + 3, ((256, 1.0),))
    rgb += (np.clip((dust - 0.8) * 5, 0, 1) * 14)[..., None]

    # Toast spots: irregular brown blotches, darkest in their middle and
    # fading out (where the dough bubbled against the griddle), and fine
    # specks between them. More and darker once toasted, and on the outside.
    blot = base_noise(BASE, seed + 5, ((26, 1.0), (64, 0.55), (150, 0.25)))
    speck = base_noise(BASE, seed + 9, ((220, 1.0), (90, 0.3)))
    lift = 0.05 * toast + (0.035 if back else 0.0)
    th = 0.68 - lift
    spot = (0.55 * smooth((blot - th) / 0.2) + 0.45 * smooth((blot - th - 0.1) / 0.12))         * (0.55 + 0.45 * toast)
    spot = np.maximum(spot, smooth((speck - (0.875 - lift)) / 0.06) * 0.45)
    darkness = (0.45 + 0.4 * toast) * (1.15 if back else 1.0)
    brown = np.array([146, 92, 44], np.float32)
    rim = 0
    mix = np.clip((spot * 0.6 + rim) * darkness, 0, 0.85)[..., None]
    rgb = rgb * (1 - mix) + brown * mix
    # The edge is a little drier and darker.
    edge = np.clip((r - 0.86) / 0.09, 0, 1) * (0.1 + 0.15 * toast)
    rgb *= (1 - edge)[..., None]
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert('RGBA')
    img.putalpha(Image.fromarray((alpha * 255).astype(np.uint8)))
    return img.filter(ImageFilter.GaussianBlur(0.5))


# ---- New ingredients (loose bits) ------------------------------------------

def finish(layer: Layer) -> Image.Image:
    """A soft shadow all round, under the bits (no light direction: the
    canvas turns every piece at random)."""
    shadow = Image.fromarray((layer.alpha * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(N * 0.01))
    sa = np.asarray(shadow, np.float32) / 255 * 0.3
    alpha = layer.alpha + sa * (1 - layer.alpha)
    return downscale(layer.rgb, alpha, PIECE)


def mix(rng, a, b):
    k = rng.uniform(0, 1)
    return tuple(np.array(a) * (1 - k) + np.array(b) * k)


def lettuce(rng, layer, texture):
    """Shredded lettuce: curling green ribbons, pale at their ribs."""
    cheese.rough_field = noise(int(rng.integers(1 << 30)), 90)
    for c in spots(rng, int(rng.integers(6, 9)), 0.27, 0.12):
        cheese.shred(layer, rng, c, rng.uniform(0.28, 0.4) * N,
                     rng.uniform(0.07, 0.1) * N,
                     mix(rng, (104, 168, 52), (176, 214, 104)), 0.05, texture,
                     0.45)


def pickles(rng, layer, texture):
    """Cucumber pickle slices: olive rim, paler flesh, a ring of seeds."""
    for c in spots(rng, int(rng.integers(2, 4)), 0.22, 0.32):
        rad = rng.uniform(0.12, 0.15) * N
        crumble(layer, rng, c, rad, texture, mix(rng, (120, 128, 46), (146, 146, 58)),
                lobes=0.03, flat=0.9, contrast=0.25, gloss=0.12,
                tint=((196, 190, 112), lambda xx, yy, x0, y0, c=c, rad=rad:
                      0.8 * smooth((0.78 - np.hypot(xx - c[0], yy - c[1]) / rad) / 0.12)))
        # Seeds: small pale dots on a ring.
        for k in range(7):
            a = k * 2 * math.pi / 7 + rng.uniform(-0.2, 0.2)
            p = (c[0] + math.cos(a) * rad * 0.36, c[1] + math.sin(a) * rad * 0.36)
            crumble(layer, rng, p, rad * 0.09, texture, (226, 220, 168),
                    lobes=0.02, flat=0.9, contrast=0.1, stretch=1.5)


def fries(rng, layer, texture):
    """French fries: golden sticks with square ends, crisper at the ends."""
    for c in spots(rng, int(rng.integers(3, 5)), 0.2, 0.17):
        ang = rng.uniform(0, math.pi)
        ca, sa = math.cos(ang), math.sin(ang)
        length = rng.uniform(0.2, 0.27) * N
        width = rng.uniform(0.038, 0.048) * N
        bend = rng.uniform(-0.06, 0.06)

        def local(dx, dy, x0, y0, ca=ca, sa=sa, length=length, width=width,
                  bend=bend):
            u = (dx * ca + dy * sa) / length
            v = (-dx * sa + dy * ca) / width - bend * u * u * length / width
            r = (np.abs(u) ** 8 + np.abs(v) ** 4) ** 0.25
            return r, smooth((1 - np.abs(v)) / 0.8)

        def ends(xx, yy, x0, y0, c=c, ca=ca, sa=sa, length=length):
            u = ((xx - c[0]) * ca + (yy - c[1]) * sa) / length
            return 0.55 * smooth((np.abs(u) - 0.7) / 0.3)

        place(layer, c, length * 1.1, local,
              mix(rng, (234, 182, 80), (246, 208, 116)), texture,
              gloss=0.05, contrast=0.3, tint=((190, 122, 40), ends))


def charred(colour, dark, stretch, lobes, count, size, gloss=0.04):
    """Meat strips with a darker, charred grain."""
    def draw(rng, layer, texture):
        for c in spots(rng, int(rng.integers(*count)), 0.27, 0.16):
            bumps = noise(int(rng.integers(1 << 30)), 120)
            k = rng.uniform(-12, 12)
            crumble(layer, rng, c, rng.uniform(*size) * N, texture,
                    tuple(v + k * w for v, w in zip(colour, (1, 0.7, 0.5))),
                    lobes=lobes, flat=0.6, contrast=0.45, gloss=gloss,
                    bumps=bumps, stretch=stretch,
                    tint=(dark, lambda xx, yy, x0, y0, b=bumps:
                          0.7 * smooth((b[yy.astype(int), xx.astype(int)] - 0.6) / 0.12)))
    return draw


BITS = {
    'lettuce': lettuce,
    'pickles': pickles,
    'fries': fries,
    # Thin shawarma strips (chicken golden, beef dark), crispy chicken in
    # rough golden chunks.
    'chicken_shawarma': charred((214, 158, 86), (140, 82, 34), 2.6, 0.18,
                                (4, 6), (0.05, 0.065)),
    'beef_shawarma': charred((128, 70, 42), (62, 30, 16), 2.8, 0.2,
                             (5, 7), (0.04, 0.055)),
    'crispy_chicken': charred((218, 150, 58), (164, 94, 30), 1.5, 0.38,
                              (3, 5), (0.085, 0.11), gloss=0.02),
}


def piece(item: str, v: int) -> Image.Image:
    rng = np.random.default_rng(sum(map(ord, item)) * 173 + v)
    texture = noise(29 + v, 120)
    layer = Layer()
    BITS[item](rng, layer, texture)
    return finish(layer)


def main() -> None:
    save_base(tortilla(21, 0.0), 'assets_src/tortilla/bases/base_tortilla_raw.webp',
              BASE_MAX)
    save_base(tortilla(21, 1.0), 'assets_src/tortilla/bases/base_tortilla_cooked.webp',
              BASE_MAX)
    # The outside of the wrap: the griddle side, mirrored like the crepe's.
    save_base(tortilla(22, 1.0, back=True).transpose(Image.FLIP_LEFT_RIGHT),
              'assets_src/animation/tortilla_back.webp', BASE_MAX)
    for item in BITS:
        for v in range(VARIANTS):
            save_piece(piece(item, v),
                       f'assets_src/tortilla/ingredients/ing_{item}_{v + 1:02d}.webp')


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    main()
