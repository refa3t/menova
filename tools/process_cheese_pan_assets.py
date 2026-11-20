"""Draws the cheese pan assets in code (owner request: no photos yet).

The pan is seen from above, like every product on the canvas: a round
cast-iron pan with two loop handles, filled with cheese. Raw: grated cheese,
not melted yet. Baked: melted, golden, browned in spots and bubbling.
Toppings are drawn inside the pan's inner wall: the definition sets the
base's `surface` to PAN_SURFACE (the cheese's radius, of half the image).

New ingredient pieces (hot dog, smoked turkey): loose single slices,
256 px, 3 variants each. Same specs as the other assets (ASSETS.md):
transparent WebP, base <= 500 KB, ingredient <= 150 KB. Deterministic.
Real photos can replace any file later under the same name.

Usage (from the repo root):
    python tools/process_cheese_pan_assets.py
Writes:
    assets_src/cheese_pan/bases/base_cheese_pan_raw.webp
    assets_src/cheese_pan/bases/base_cheese_pan_cooked.webp
    assets_src/cheese_pan/ingredients/ing_<id>_<n>.webp
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from process_crepe_assets import (BASE, BASE_MAX, PIECE, PIECE_MAX, finish,
                                  noise, radial, save, shade)

# Radii of the pan, of half the image: the cheese inside the inner wall,
# the inner wall, the rim's outer edge, and the handles' reach.
PAN_SURFACE = 0.74
WALL = 0.80
RIM = 0.88
HANDLE = 0.985


def _alpha_img(rgb, alpha) -> Image.Image:
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert('RGBA')
    img.putalpha(Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8)))
    return img


def pan_shell():
    """The empty cast-iron pan: rim, inner wall, floor and two handles.
    Returns its RGB and alpha (the floor is later covered by cheese)."""
    r, a = radial(BASE)
    yy, xx = np.mgrid[0:BASE, 0:BASE].astype(np.float32) / BASE
    n = noise(BASE, 71, ((20, 1.0), (90, 0.5), (260, 0.3)))
    iron = np.array([38, 36, 35], np.float32)
    rgb = np.broadcast_to(iron, (BASE, BASE, 3)) * (0.82 + 0.35 * n)[..., None]
    # Rim: rounded lip, lit from the top left.
    lip = np.clip(1 - np.abs(r - (WALL + RIM) / 2) / ((RIM - WALL) / 2), 0, 1)
    light = np.clip(-np.cos(a + math.pi / 4), 0, 1)  # top left
    rgb += (lip ** 1.5 * (18 + 55 * light))[..., None]
    # Inner wall in shade on the lit side (it faces away from the light).
    wall = np.clip((r - PAN_SURFACE) / (WALL - PAN_SURFACE), 0, 1) * (r < WALL)
    rgb *= (1 - 0.35 * wall * light)[..., None]
    # Handles: a loop on each side (left and right), the same iron.
    handles = np.zeros((BASE, BASE), np.float32)
    for side in (-1, 1):
        cx = 0.5 + side * (HANDLE - 0.12) / 2
        d = np.hypot((xx - cx) / 0.06, (yy - 0.5) / 0.1)
        handles = np.maximum(handles, np.clip((1 - np.abs(d - 0.75) / 0.25) * 4, 0, 1))
    handles *= (r > RIM - 0.02)
    body = np.clip((RIM - r) * BASE / 3, 0, 1)
    alpha = np.maximum(body, handles)
    # A soft highlight along each handle's top.
    rgb += (handles * (1 - body) * 30 * np.clip(0.5 - yy, 0, 1) * 2)[..., None]
    return rgb, alpha, r, a


def raw_cheese(r, a):
    """Grated cheese heaped in the pan: pale shreds over a creamy layer."""
    rgb = np.broadcast_to(np.array([236, 222, 180], np.float32),
                          (BASE, BASE, 3)).copy()
    rgb *= (0.92 + 0.1 * noise(BASE, 81))[..., None]
    shreds = Image.new('RGBA', (BASE, BASE), (0, 0, 0, 0))
    d = ImageDraw.Draw(shreds)
    rng = np.random.default_rng(82)
    c = BASE / 2
    for _ in range(2200):
        rr = math.sqrt(rng.random()) * PAN_SURFACE * c * 0.98
        th = rng.random() * 2 * math.pi
        x, y = c + rr * math.cos(th), c + rr * math.sin(th)
        ang = rng.random() * math.pi
        ln = rng.uniform(18, 44)
        dx, dy = math.cos(ang) * ln / 2, math.sin(ang) * ln / 2
        tone = rng.uniform(0.86, 1.06)
        yellow = rng.random() < 0.3  # some cheddar among the mozzarella
        base = (238, 196, 110) if yellow else (248, 240, 214)
        col = tuple(int(min(255, v * tone)) for v in base)
        d.line([(x - dx, y - dy), (x + dx, y + dy)], fill=col + (255,),
               width=int(rng.integers(5, 10)))
    arr = np.asarray(shreds.filter(ImageFilter.GaussianBlur(0.6)), np.float32)
    sa = arr[..., 3:] / 255
    rgb = rgb * (1 - sa) + arr[..., :3] * sa
    # Shadow where the cheese meets the wall.
    rgb *= (1 - 0.35 * np.clip((r - PAN_SURFACE + 0.04) / 0.04, 0, 1))[..., None]
    return rgb


def baked_cheese(r, a):
    """Melted cheese: smooth golden layer, browned blisters, oil sheen and
    bubbles; darker where it caramelised against the hot wall."""
    n = noise(BASE, 91, ((10, 1.0), (30, 0.6), (90, 0.3)))
    melt = np.array([246, 204, 110], np.float32)
    gold = np.array([232, 168, 64], np.float32)
    brown = np.array([150, 86, 34], np.float32)
    t = np.clip(n * 1.2 - 0.1, 0, 1)[..., None]
    rgb = melt * (1 - t) + gold * t
    blister = noise(BASE, 92, ((26, 1.0), (70, 0.5)))
    spots = np.clip((blister - 0.62) * 5, 0, 1) * 0.75
    edge = np.clip((r - PAN_SURFACE + 0.09) / 0.09, 0, 1) * 0.65
    mix = np.clip(spots + edge, 0, 0.9)[..., None]
    rgb = rgb * (1 - mix) + brown * mix
    # Bubbles: small domes with a light top and a dark ring.
    rng = np.random.default_rng(93)
    yy, xx = np.mgrid[0:BASE, 0:BASE].astype(np.float32)
    c = BASE / 2
    for _ in range(46):
        rr = math.sqrt(rng.random()) * PAN_SURFACE * c * 0.9
        th = rng.random() * 2 * math.pi
        bx, by = c + rr * math.cos(th), c + rr * math.sin(th)
        br = rng.uniform(6, 15)
        x0, x1 = int(max(bx - br * 2, 0)), int(min(bx + br * 2, BASE))
        y0, y1 = int(max(by - br * 2, 0)), int(min(by + br * 2, BASE))
        dd = np.hypot(xx[y0:y1, x0:x1] - bx, yy[y0:y1, x0:x1] - by) / br
        ring = np.clip(1 - np.abs(dd - 1) * 3, 0, 1) * 0.4
        top = np.clip(1 - np.hypot(xx[y0:y1, x0:x1] - bx + br * 0.3,
                                   yy[y0:y1, x0:x1] - by + br * 0.3) / (br * 0.5), 0, 1)
        sub = rgb[y0:y1, x0:x1]
        sub *= (1 - ring)[..., None]
        sub += (top * 70)[..., None]
    # Oil sheen, top left.
    sheen = np.exp(-(((xx / BASE - 0.38) ** 2) + ((yy / BASE - 0.36) ** 2)) / 0.02)
    rgb += (sheen * 28)[..., None]
    rgb *= (1 - 0.3 * np.clip((r - PAN_SURFACE + 0.02) / 0.02, 0, 1))[..., None]
    return rgb


def pan(cooked: bool) -> Image.Image:
    rgb, alpha, r, a = pan_shell()
    cheese = baked_cheese(r, a) if cooked else raw_cheese(r, a)
    inside = np.clip((PAN_SURFACE - r) * BASE / 2.5, 0, 1)[..., None]
    rgb = rgb * (1 - inside) + cheese * inside
    return _alpha_img(rgb, alpha).filter(ImageFilter.GaussianBlur(0.4))


# ---- New ingredient pieces -----------------------------------------------

def hot_dog(v: int) -> Image.Image:
    """A hot dog coin: reddish skin ring, pink inside, slightly oval."""
    r, a = radial(PIECE)
    rng = np.random.default_rng(1200 + v)
    squash = rng.uniform(0.85, 1.0)
    yy, xx = np.mgrid[0:PIECE, 0:PIECE].astype(np.float32)
    c = (PIECE - 1) / 2
    rr = np.hypot((xx - c) / (c * 0.62), (yy - c) / (c * 0.62 * squash))
    alpha = np.clip((1 - rr) * PIECE / 5, 0, 1)
    inner = np.array([222, 128, 112], np.float32)
    skin = np.array([170, 62, 44], np.float32)
    t = np.clip((rr - 0.8) / 0.12, 0, 1)[..., None]
    rgb = inner * (1 - t) + skin * t
    n = noise(PIECE, 1300 + v, ((14, 1.0), (50, 0.5)))
    rgb *= (0.9 + 0.16 * n)[..., None]
    # Seared on top in the oven: a faint brown blush.
    rgb *= (1 - 0.12 * np.clip(1 - rr, 0, 1))[..., None]
    img = finish(shade(rgb, alpha, 0.3), alpha)
    return img.rotate(int(rng.integers(0, 180)), resample=Image.BICUBIC)


def smoked_turkey(v: int) -> Image.Image:
    """A thin smoked turkey slice, loosely folded: pale pink with a darker
    smoked edge and a crease."""
    rng = np.random.default_rng(1400 + v)
    yy, xx = np.mgrid[0:PIECE, 0:PIECE].astype(np.float32)
    c = (PIECE - 1) / 2
    _, ang = radial(PIECE)
    wob = sum(0.05 / (k + 1) * np.sin(ang * (k + 2) + rng.random() * 6.28)
              for k in range(3))
    rr = np.hypot((xx - c) / (c * 0.78), (yy - c) / (c * 0.56))
    edge = 1 + wob
    alpha = np.clip((edge - rr) * PIECE / 6, 0, 1)
    flesh = np.array([236, 182, 166], np.float32)
    smoked = np.array([176, 104, 74], np.float32)
    t = np.clip((rr - edge + 0.16) / 0.14, 0, 1)[..., None]
    rgb = flesh * (1 - t) + smoked * t
    n = noise(PIECE, 1500 + v, ((8, 1.0), (30, 0.6), (90, 0.3)))
    rgb *= (0.9 + 0.16 * n)[..., None]
    # A fold across the slice: a light ridge beside a soft shadow.
    k = rng.uniform(-0.4, 0.4)
    dist = ((yy - c) - k * (xx - c)) / PIECE
    rgb *= (1 - 0.18 * np.exp(-((dist + 0.03) / 0.03) ** 2))[..., None]
    rgb += (22 * np.exp(-((dist - 0.01) / 0.02) ** 2))[..., None]
    img = finish(shade(rgb, alpha, 0.25), alpha)
    return img.rotate(int(rng.integers(0, 180)), resample=Image.BICUBIC)


PIECES = {'hot_dog': hot_dog, 'smoked_turkey': smoked_turkey}


def main() -> None:
    save(pan(False), 'assets_src/cheese_pan/bases/base_cheese_pan_raw.webp', BASE_MAX)
    save(pan(True), 'assets_src/cheese_pan/bases/base_cheese_pan_cooked.webp', BASE_MAX)
    for key, draw in PIECES.items():
        for v in range(3):
            save(draw(v),
                 f'assets_src/cheese_pan/ingredients/ing_{key}_{v + 1:02d}.webp',
                 PIECE_MAX)


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    main()
