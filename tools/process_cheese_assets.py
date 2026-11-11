"""Draws the cheese pieces in code (owner request: grated cheese spread
evenly over the product, not piles or lumps).

Mozzarella, cheddar and roumi are grated: each piece is a generous
sprinkle of flat, curling shreds spread over it (owner: a lot of cheese, not
a little), thinning towards its edge so pieces blend into one even layer.
Parmesan is finely grated: many small flakes. Feta and blue cheese cannot
be grated: each piece is a scatter of crumbles (blue cheese with fine
veins). The colours come from the cheese photos
(assets_src/pizza/ingredients/ing_<id>_01.webp, kept as the reference).
Lighting is all round (no light direction, no offset shadow), because the
canvas turns every piece at random.

Usage (from the repo root): python tools/process_cheese_assets.py
Writes assets_src/pizza/ingredients/ing_<id>_g01..g06.webp (224 px, <= 150 KB).
"""
import math
import os

import numpy as np
from PIL import Image, ImageFilter

PIECE = 224
SS = 3  # drawn at 3x, then reduced: smooth edges
N = PIECE * SS
MAX = 150 * 1024
VARIANTS = 6

# id: (style, colour sampled from the photo, gloss)
CHEESES = {
    'mozzarella': ('grated', (241, 235, 209), 0.1),
    'cheddar': ('grated', (247, 178, 38), 0.06),
    'roumi': ('grated', (240, 214, 162), 0.04),
    'parmesan': ('flakes', (236, 218, 176), 0.0),
    'feta': ('crumble', (242, 240, 230), 0.0),
    'blue_cheese': ('blue', (230, 226, 206), 0.0),
}


def noise(seed: int, cells: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    grid = rng.random((cells, cells)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
    return np.asarray(img, np.float32) / 255


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


class Layer:
    """Pieces composited one over another (premultiplied colour)."""

    def __init__(self):
        self.rgb = np.zeros((N, N, 3), np.float32)
        self.alpha = np.zeros((N, N), np.float32)

    def add(self, cover, height, colour, gloss, texture, contrast=0.22):
        shade = 1 - contrast + contrast * height
        rgb = np.asarray(colour, np.float32)[None, None, :] * shade[..., None]
        rgb = rgb * (0.9 + 0.13 * texture)[..., None]
        rgb = rgb + 255 * gloss * (height ** 6)[..., None]
        self.rgb = rgb * cover[..., None] + self.rgb * (1 - cover[..., None])
        self.alpha = cover + self.alpha * (1 - cover)


def shred(layer, rng, centre, length, width, colour, gloss, texture, rough):
    """One shred: a flat ribbon that curls a little, its edges ragged and its
    width wavering, the ends cut blunt."""
    angle = rng.uniform(0, math.pi)
    d = np.array([math.cos(angle), math.sin(angle)])
    n = np.array([-d[1], d[0]])
    p0 = np.array(centre) - d * length / 2
    p3 = np.array(centre) + d * length / 2
    # An S or a C curl.
    b1, b2 = rng.uniform(-0.38, 0.38, 2) * length
    p1 = p0 + d * length / 3 + n * b1
    p2 = p0 + d * 2 * length / 3 + n * b2
    ts = np.linspace(0, 1, 110)
    u = 1 - ts
    pts = ((u ** 3)[:, None] * p0 + (3 * u * u * ts)[:, None] * p1
           + (3 * u * ts * ts)[:, None] * p2 + (ts ** 3)[:, None] * p3)
    phase = rng.uniform(0, 6.28)
    half = width / 2 * (0.82 + 0.18 * np.sin(ts * rng.uniform(6, 11) + phase))
    half = half * (0.78 + 0.22 * smooth(np.minimum(ts, 1 - ts) / 0.08))
    x0, y0 = np.floor(pts.min(0) - width - 2).astype(int)
    x1, y1 = np.ceil(pts.max(0) + width + 2).astype(int)
    x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, N), min(y1, N)
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    best = np.full(xx.shape, 9.0, np.float32)
    for (px, py), h in zip(pts, half):
        best = np.minimum(best, np.hypot(xx - px, yy - py) / h)
    # Ragged edges: the boundary wanders with fine noise.
    best = best * (1 + rough * (rough_field[y0:y1, x0:x1] - 0.5))
    cover = np.zeros((N, N), np.float32)
    height = np.zeros((N, N), np.float32)
    cover[y0:y1, x0:x1] = (best <= 1).astype(np.float32)
    # Flat on top, falling off only near its edges (a ribbon, not a tube).
    height[y0:y1, x0:x1] = smooth((1 - best) / 0.45)
    layer.add(cover, height, colour, gloss, texture)


def crumble(layer, rng, centre, size, colour, gloss, texture, angular,
            pitted, veins=None):
    """One crumble: a small, ragged, matte lump."""
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    dx, dy = xx - centre[0], yy - centre[1]
    a = np.arctan2(dy, dx)
    edge = 1 + sum(rng.uniform(0.04, 0.1) * angular / k
                   * np.sin(a * k + rng.uniform(0, 6.28)) for k in range(2, 8))
    edge = edge + 0.12 * (rough_field - 0.5)
    r = np.hypot(dx, dy) / (size * edge)
    cover = (r <= 1).astype(np.float32)
    height = smooth((1 - r) / 0.5)
    if pitted:
        pits = smooth((noise(int(rng.integers(1 << 30)), 70) - 0.66) / 0.1)
        height = height * (1 - 0.18 * pits)
    layer.add(cover, height, colour, gloss, texture, contrast=0.2)
    if veins is not None:
        v = smooth((noise(int(rng.integers(1 << 30)), 64) - 0.7) / 0.06)
        v = np.maximum(v, smooth((noise(int(rng.integers(1 << 30)), 130) - 0.8) / 0.05))
        v = v * cover * smooth(height / 0.3)
        blue = np.asarray(veins, np.float32)[None, None, :]
        layer.rgb = layer.rgb * (1 - v[..., None] * 0.75) + blue * v[..., None] * 0.75


def spots(rng, count, radius, gap):
    """Centres spread evenly over a disc of [radius] (of the piece) around
    its middle, at least [gap] apart (a sprinkle, never a heap)."""
    out = []
    tries = 0
    while len(out) < count and tries < 4000:
        tries += 1
        r = radius * math.sqrt(rng.random())
        t = rng.random() * 2 * math.pi
        p = np.array([0.5 + r * math.cos(t), 0.5 + r * math.sin(t)]) * N
        if all(np.hypot(*(p - q)) > N * gap for q in out):
            out.append(p)
    return out


rough_field = None


def piece(cheese: str, v: int) -> Image.Image:
    global rough_field
    style, colour, gloss = CHEESES[cheese]
    rng = np.random.default_rng(sum(map(ord, cheese)) * 101 + v)
    texture = noise(7 + v, 110)
    rough_field = noise(1000 + v, 90)
    layer = Layer()
    if style == 'grated':
        for c in spots(rng, int(rng.integers(10, 13)), 0.25, 0.085):
            shred(layer, rng, c, rng.uniform(0.26, 0.36) * N,
                  rng.uniform(0.06, 0.075) * N, colour, gloss, texture, 0.35)
    elif style == 'flakes':
        for c in spots(rng, int(rng.integers(26, 33)), 0.4, 0.06):
            crumble(layer, rng, c, rng.uniform(0.022, 0.04) * N, colour, gloss,
                    texture, angular=1.6, pitted=False)
    else:
        for c in spots(rng, int(rng.integers(7, 10)), 0.33, 0.13):
            crumble(layer, rng, c, rng.uniform(0.05, 0.075) * N, colour, gloss,
                    texture, angular=1.3, pitted=True,
                    veins=(86, 116, 118) if style == 'blue' else None)
    # A soft shadow all round, under the pieces.
    shadow = Image.fromarray((layer.alpha * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(N * 0.012))
    sa = np.asarray(shadow, np.float32) / 255 * 0.32
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
    for cheese in CHEESES:
        for v in range(VARIANTS):
            save(piece(cheese, v), f'{out}/ing_{cheese}_g{v + 1:02d}.webp')


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    main()
