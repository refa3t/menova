"""Draws the crepe assets in code (owner request: no photos yet).

Bases (1024 px, transparent, <= 500 KB) and sweet ingredients (256 px,
3 variants each, <= 150 KB), same specs as the pizza assets (ASSETS.md).
Real photos can replace any file later under the same name.

Usage (from the repo root):
    python tools/process_crepe_assets.py
Writes:
    assets_src/crepe/bases/base_crepe_raw.webp
    assets_src/crepe/bases/base_crepe_cooked.webp
    assets_src/animation/crepe_back.webp (the back, for the fold)
    assets_src/animation/griddle_surface.webp
    assets_src/crepe/ingredients/ing_<id>_<n>.webp
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

BASE = 1024
PIECE = 256
BASE_MAX = 500 * 1024
PIECE_MAX = 150 * 1024


def noise(size: int, seed: int, octaves=((8, 1.0), (24, 0.5), (64, 0.25))):
    """Smooth value noise in [0, 1] from upscaled random grids."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((size, size), np.float32)
    total = 0.0
    for cells, weight in octaves:
        grid = rng.random((cells, cells)).astype(np.float32)
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (size, size), Image.BICUBIC)
        acc += np.asarray(img, np.float32) / 255 * weight
        total += weight
    acc /= total
    return (acc - acc.min()) / (acc.max() - acc.min() + 1e-6)


def radial(size: int):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    dx, dy = xx - c, yy - c
    return np.hypot(dx, dy) / c, np.arctan2(dy, dx)


def save(img: Image.Image, path: str, limit: int) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    q = 92
    while True:
        img.save(path, 'WEBP', quality=q, method=6)
        if os.path.getsize(path) <= limit or q <= 50:
            break
        q -= 6
    print(f'{path}: {os.path.getsize(path) // 1024} KB')


def disc_mask(size: int, seed: int, wobble=0.012, radius=0.96):
    """Round, slightly irregular edge like a poured crepe."""
    r, a = radial(size)
    rng = np.random.default_rng(seed)
    edge = radius + sum(
        wobble / (k + 1) * math.sin(0) + wobble / (k + 1) * np.sin(
            a * (k + 3) + rng.random() * 6.28)
        for k in range(4))
    alpha = np.clip((edge - r) * size / 3, 0, 1)
    return alpha, r


def crepe(seed: int, cook: float, back=False) -> Image.Image:
    """cook 0 = raw batter, 1 = golden with lacy browning."""
    alpha, r = disc_mask(BASE, seed)
    n_big = noise(BASE, seed)
    # Lace: large soft patches with fine detail (a crepe browns in a net
    # pattern, not in even speckles).
    n_lace = noise(BASE, seed + 1, ((14, 1.0), (40, 0.6), (120, 0.25)))
    raw = np.array([243, 222, 176], np.float32)
    gold = np.array([236, 190, 120], np.float32)
    brown = np.array([176, 108, 52], np.float32)
    col = raw * (1 - cook) + gold * cook
    rgb = np.broadcast_to(col, (BASE, BASE, 3)).copy()
    # Soft tone variation.
    rgb *= (0.94 + 0.1 * n_big)[..., None]
    # Lacy browning: brown where the lace noise peaks (more on the back,
    # which touched the griddle longer).
    lace_amt = (0.1 + 0.6 * cook) * (1.35 if back else 1.0)
    lace = np.clip((n_lace - (0.52 if back else 0.58)) * 3.5, 0, 1) * lace_amt
    rim = np.clip((r - 0.82) / 0.14, 0, 1) * (0.25 + 0.5 * cook)
    mix = np.clip(lace + rim * 0.6, 0, 1)[..., None]
    rgb = rgb * (1 - mix) + brown * mix
    # Raw batter has a faint sheen; cooked has tiny holes (darker dots).
    if cook < 0.5:
        sheen = np.clip(1 - np.hypot(*(np.mgrid[0:BASE, 0:BASE] - BASE * 0.38)) / (BASE * 0.5), 0, 1)
        rgb += (sheen * 18 * (1 - cook))[..., None]
    else:
        holes = noise(BASE, seed + 7, ((180, 1.0),))
        dots = np.clip((holes - 0.9) * 10, 0, 1)[..., None] * 0.25
        rgb = rgb * (1 - dots) + brown * 0.7 * dots
    a = (alpha * 255).astype(np.uint8)
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert('RGBA')
    img.putalpha(Image.fromarray(a))
    return img.filter(ImageFilter.GaussianBlur(0.4))


def griddle() -> Image.Image:
    """Round dark steel plate with a soft sheen and a rim."""
    r, a = radial(BASE)
    n = noise(BASE, 41, ((16, 1.0), (64, 0.5), (200, 0.3)))
    steel = np.array([46, 44, 42], np.float32)
    rgb = np.broadcast_to(steel, (BASE, BASE, 3)).copy()
    rgb *= (0.85 + 0.3 * n)[..., None]
    yy, xx = np.mgrid[0:BASE, 0:BASE] / BASE
    sheen = np.exp(-(((xx - 0.36) ** 2) + ((yy - 0.32) ** 2)) / 0.03)
    rgb += (sheen * 40)[..., None]
    rim = np.clip((r - 0.93) / 0.04, 0, 1)
    rgb = rgb * (1 - rim[..., None] * 0.5)
    alpha = np.clip((0.995 - r) * BASE / 3, 0, 1)
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert('RGBA')
    img.putalpha(Image.fromarray((alpha * 255).astype(np.uint8)))
    return img


# ---- Sweet ingredients ---------------------------------------------------

def blob_mask(seed: int, lobes: int, wobble: float, radius: float):
    r, a = radial(PIECE)
    rng = np.random.default_rng(seed)
    edge = radius + sum(
        wobble / (k + 1) * np.sin(a * (lobes + k) + rng.random() * 6.28)
        for k in range(3))
    return np.clip((edge - r) * PIECE / 4, 0, 1), r


def shade(rgb, alpha, light=0.35):
    """Top-left light, soft gloss highlight."""
    yy, xx = np.mgrid[0:PIECE, 0:PIECE] / PIECE
    rgb = rgb * (1 + light * (0.5 - (xx * 0.6 + yy * 0.4)))[..., None]
    return rgb


def finish(rgb, alpha, shadow=True) -> Image.Image:
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert('RGBA')
    img.putalpha(Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8)))
    if not shadow:
        return img
    sh = Image.new('RGBA', img.size, (0, 0, 0, 0))
    sa = img.getchannel('A').filter(ImageFilter.GaussianBlur(5)).point(lambda v: v * 0.35)
    sh.putalpha(sa)
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.alpha_composite(sh, (3, 5))
    out.alpha_composite(img)
    return out


def nutella(v: int) -> Image.Image:
    alpha, r = blob_mask(100 + v, 3 + v, 0.09, 0.62)
    base = np.array([74, 38, 20], np.float32)
    n = noise(PIECE, 200 + v, ((6, 1.0), (20, 0.5)))
    rgb = np.broadcast_to(base, (PIECE, PIECE, 3)) * (0.85 + 0.35 * n)[..., None]
    swirl = np.sin(r * 22 + noise(PIECE, 300 + v, ((5, 1.0),)) * 6) * 0.5 + 0.5
    rgb = rgb * (0.9 + 0.15 * swirl)[..., None]
    yy, xx = np.mgrid[0:PIECE, 0:PIECE] / PIECE
    gloss = np.exp(-(((xx - 0.38) ** 2) / 0.006 + ((yy - 0.36) ** 2) / 0.02)) * 120
    rgb = shade(rgb + gloss[..., None], alpha)
    return finish(rgb, alpha)


def white_chocolate(v: int) -> Image.Image:
    """A creamy zigzag drizzle."""
    img = Image.new('L', (PIECE, PIECE), 0)
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(400 + v)
    pts = []
    for i in range(7):
        x = 40 + i * 29 + rng.integers(-6, 6)
        y = 70 if i % 2 == 0 else 186
        pts.append((x, y + rng.integers(-12, 12)))
    d.line(pts, fill=255, width=20, joint='curve')
    for p in pts:
        d.ellipse([p[0] - 10, p[1] - 10, p[0] + 10, p[1] + 10], fill=255)
    img = img.rotate(rng.integers(0, 180), resample=Image.BICUBIC)
    alpha = np.asarray(img.filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
    base = np.array([246, 238, 220], np.float32)
    n = noise(PIECE, 500 + v, ((12, 1.0),))
    rgb = np.broadcast_to(base, (PIECE, PIECE, 3)) * (0.93 + 0.08 * n)[..., None]
    edge = np.asarray(img.filter(ImageFilter.GaussianBlur(4)), np.float32) / 255
    rgb = rgb * (0.82 + 0.18 * edge)[..., None]
    return finish(rgb, alpha)


def lotus(v: int) -> Image.Image:
    """Caramelised biscuit crumbs."""
    rng = np.random.default_rng(600 + v)
    img = Image.new('RGBA', (PIECE, PIECE), (0, 0, 0, 0))
    for _ in range(26):
        size = rng.integers(16, 42)
        cx, cy = rng.normal(PIECE / 2, 42, 2)
        pts = [(cx + math.cos(t) * size * (0.6 + 0.4 * rng.random()),
                cy + math.sin(t) * size * (0.6 + 0.4 * rng.random()))
               for t in np.linspace(0, 2 * math.pi, rng.integers(5, 8), endpoint=False)]
        shade_ = rng.uniform(0.8, 1.1)
        col = tuple(int(c * shade_) for c in (196, 120, 58))
        piece = Image.new('RGBA', (PIECE, PIECE), (0, 0, 0, 0))
        ImageDraw.Draw(piece).polygon(pts, fill=col + (255,))
        img.alpha_composite(piece)
    arr = np.asarray(img, np.float32)
    n = noise(PIECE, 700 + v, ((40, 1.0),))
    arr[..., :3] *= (0.85 + 0.3 * n)[..., None]
    return finish(arr[..., :3], arr[..., 3] / 255)


def banana(v: int) -> Image.Image:
    """A round banana slice: pale rim, creamy flesh, seed ring."""
    alpha, r = blob_mask(800 + v, 5, 0.02, 0.8)
    flesh = np.array([246, 233, 178], np.float32)
    rim = np.array([226, 205, 130], np.float32)
    t = np.clip((r - 0.62) / 0.16, 0, 1)[..., None]
    rgb = flesh * (1 - t) + rim * t
    n = noise(PIECE, 900 + v, ((10, 1.0), (40, 0.4)))
    rgb = rgb * (0.94 + 0.1 * n)[..., None]
    _, a = radial(PIECE)
    rng = np.random.default_rng(950 + v)
    seeds = np.zeros((PIECE, PIECE), np.float32)
    for k in range(9):
        ang = k * 2 * math.pi / 9 + rng.random() * 0.2
        cx = PIECE / 2 + math.cos(ang) * PIECE * 0.13
        cy = PIECE / 2 + math.sin(ang) * PIECE * 0.13
        yy, xx = np.mgrid[0:PIECE, 0:PIECE]
        seeds += np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / 14)
    rgb = rgb * (1 - np.clip(seeds, 0, 1)[..., None] * 0.45)
    center = np.exp(-(r / 0.12) ** 2)
    rgb = rgb * (1 - center[..., None] * 0.12)
    return finish(shade(rgb, alpha, 0.2), alpha)


def strawberry(v: int) -> Image.Image:
    """A strawberry cut lengthwise: heart shape, pale core, seeds."""
    yy, xx = np.mgrid[0:PIECE, 0:PIECE].astype(np.float32)
    x = (xx - PIECE / 2) / (PIECE * 0.36)
    y = (yy - PIECE * 0.46) / (PIECE * 0.36)
    heart = (x ** 2 + (1.15 * y - np.sqrt(np.abs(x)) * 0.55) ** 2)
    alpha = np.clip((1.0 - heart) * 18, 0, 1)
    red = np.array([206, 32, 46], np.float32)
    pale = np.array([250, 196, 196], np.float32)
    core = np.clip(1 - heart / 0.45, 0, 1)
    veins = (np.sin(np.arctan2(y, x) * 9) * 0.5 + 0.5) * np.clip(1 - heart / 0.8, 0, 1) * 0.35
    t = np.clip(core * 0.85 + veins, 0, 1)[..., None]
    rgb = red * (1 - t) + pale * t
    rng = np.random.default_rng(1000 + v)
    for _ in range(14):
        ang = rng.random() * 2 * math.pi
        rr = rng.uniform(0.78, 0.92)
        sx = PIECE / 2 + math.cos(ang) * PIECE * 0.33 * rr
        sy = PIECE * 0.46 + math.sin(ang) * PIECE * 0.3 * rr
        d = np.exp(-((xx - sx) ** 2 + (yy - sy) ** 2) / 6)
        rgb = rgb * (1 - d[..., None] * 0.6) + np.array([250, 225, 120]) * d[..., None] * 0.6
    # Flip so the wide end (stem) is on top and the tip points down.
    img = finish(shade(rgb, alpha, 0.25), alpha).transpose(Image.FLIP_TOP_BOTTOM)
    return img.rotate(rng.integers(-40, 40), resample=Image.BICUBIC)


SWEETS = {
    'nutella': nutella,
    'white_chocolate': white_chocolate,
    'lotus': lotus,
    'banana': banana,
    'strawberry': strawberry,
}


def half_moon(img: Image.Image) -> Image.Image:
    """The crepe as served (owner request): a half circle, curved side up and
    the straight edge at 3/4 of the height, so the filling sits in its middle
    and the sides fold over it."""
    w, h = img.size
    top = img.crop((0, 0, w, h // 2))
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    out.alpha_composite(top, (0, h // 4))
    # A soft straight edge (the batter folded under).
    edge = Image.new('L', (w, h), 0)
    ImageDraw.Draw(edge).rectangle((0, h // 4, w, h * 3 // 4 - 3), fill=255)
    alpha = Image.fromarray(np.minimum(
        np.asarray(out.getchannel('A')),
        np.asarray(edge.filter(ImageFilter.GaussianBlur(1.5)))))
    out.putalpha(alpha)
    return out


def main() -> None:
    save(half_moon(crepe(11, 0.0)), 'assets_src/crepe/bases/base_crepe_raw.webp', BASE_MAX)
    save(half_moon(crepe(11, 1.0)), 'assets_src/crepe/bases/base_crepe_cooked.webp', BASE_MAX)
    save(half_moon(crepe(11, 1.0, back=True).transpose(Image.FLIP_LEFT_RIGHT)),
         'assets_src/animation/crepe_back.webp', BASE_MAX)
    save(griddle(), 'assets_src/animation/griddle_surface.webp', BASE_MAX)
    for key, draw in SWEETS.items():
        for v in range(3):
            save(draw(v), f'assets_src/crepe/ingredients/ing_{key}_{v + 1:02d}.webp',
                 PIECE_MAX)


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    main()
