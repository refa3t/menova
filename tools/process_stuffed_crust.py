"""Builds the stuffed-crust base from the regular base (owner request).

The crust ring is widened (polar remap: the sauce shrinks inward, the crust
texture stretches over the wider ring) and shaded so the rim reads as a
thick rolled edge filled with cheese: a raised highlight along the ring,
a soft shadow cast on the sauce, a fold seam and a browned outer edge.

Usage (from the repo root):
    python tools/process_stuffed_crust.py
Writes assets_src/pizza/bases/base_pizza_stuffed_raw.webp (<= 500 KB).
"""
import os

import numpy as np
from PIL import Image, ImageFilter

SRC = 'assets_src/pizza/bases/base_pizza_regular_raw.webp'
OUT = 'assets_src/pizza/bases/base_pizza_stuffed_raw.webp'

SAUCE_EDGE = 450   # measured sauce/crust boundary on the regular base (px)
NEW_EDGE = 392     # sauce/crust boundary on the stuffed base (px)
MAX_BYTES = 500 * 1024


def bilinear(img: np.ndarray, y: np.ndarray, x: np.ndarray) -> np.ndarray:
    h, w = img.shape[:2]
    x = np.clip(x, 0, w - 1.001)
    y = np.clip(y, 0, h - 1.001)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = (x - x0)[..., None], (y - y0)[..., None]
    a, b = img[y0, x0], img[y0, x0 + 1]
    c, d = img[y0 + 1, x0], img[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def main() -> None:
    src = np.asarray(Image.open(SRC).convert('RGBA')).astype(np.float32)
    h, w = src.shape[:2]
    cy, cx = (h - 1) / 2, (w - 1) / 2
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dy, dx = yy - cy, xx - cx
    r = np.hypot(dy, dx)
    outer = 503.0

    # Polar remap: [0, NEW_EDGE] <- [0, SAUCE_EDGE]; [NEW_EDGE, outer] <-
    # [SAUCE_EDGE, outer].
    src_r = np.where(
        r <= NEW_EDGE,
        r * SAUCE_EDGE / NEW_EDGE,
        SAUCE_EDGE + (r - NEW_EDGE) * (outer - SAUCE_EDGE) / (outer - NEW_EDGE),
    )
    scale = np.where(r > 0, src_r / np.maximum(r, 1e-6), 1)
    out = bilinear(src, cy + dy * scale, cx + dx * scale)

    rgb, alpha = out[..., :3], out[..., 3:4]
    ring = (r - NEW_EDGE) / (outer - NEW_EDGE)  # 0 at sauce edge, 1 outside

    # Raised rolled edge: brighter along the crest, darker toward both sides.
    crest = np.exp(-((ring - 0.45) / 0.28) ** 2)
    light = np.where((ring >= 0) & (ring <= 1), 0.86 + 0.24 * crest, 1.0)
    # Fold seam where the dough was rolled over the cheese.
    seam = np.exp(-((ring - 0.16) / 0.035) ** 2) * 0.16
    # Browned outer lip.
    lip = np.clip((ring - 0.82) / 0.18, 0, 1) * 0.12
    # Shadow the raised rim casts on the sauce.
    shadow = np.where(ring < 0, np.exp(ring * (outer - NEW_EDGE) / 14) * 0.28, 0)
    factor = (light - seam - lip - shadow)[..., None]
    rgb = rgb * factor

    # Warm golden tone on the crust (baked cheese-filled dough).
    warm = np.array([1.04, 1.0, 0.9], dtype=np.float32)
    in_ring = ((ring >= 0) & (ring <= 1))[..., None]
    rgb = np.where(in_ring, rgb * warm, rgb)

    img = Image.fromarray(
        np.concatenate([np.clip(rgb, 0, 255), alpha], axis=-1).astype(np.uint8),
        'RGBA',
    )
    # Soften the shading bands slightly without blurring the texture much.
    soft = img.filter(ImageFilter.GaussianBlur(0.6))
    img = Image.blend(img, soft, 0.5)

    quality = 92
    while True:
        img.save(OUT, 'WEBP', quality=quality, method=6)
        if os.path.getsize(OUT) <= MAX_BYTES or quality <= 60:
            break
        quality -= 4
    print(f'{OUT}: {os.path.getsize(OUT) // 1024} KB (q={quality})')


if __name__ == '__main__':
    main()
