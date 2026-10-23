"""Cut raw owner photos into transparent, spec-compliant WebP assets.

Usage (from repo root):  python tools/process_assets.py
Input:  assets_src/_raw/*.jpg   Output: assets_src/pizza/{bases,ingredients}/
Background is pure white; alpha is derived from distance to white.
"""
import os
from pathlib import Path

import numpy as np
from PIL import Image

RAW = Path('assets_src/_raw')
OUT = Path('assets_src/pizza')
ING_MAX_SIDE, ING_MAX_BYTES = 256, 150 * 1024
BASE_SIDE, BASE_MAX_BYTES = 1024, 500 * 1024

# Ingredient names are the keys from PIZZA_CATALOG.md section 2.
# Raw file -> layout. 'single': one item. 'grid': 4x2 sheet, row-major names.
SOURCES = {
    'bizza.jpg': ('base', 'base_pizza_regular_raw'),
    'AaFqmfj7-CIj0mEfkh9uOw-AaFqmfj7JMer-vn9icu6hg.jpg': ('single', 'mozzarella'),
    'AaFqmgxihmESsgsH33ooNw-AaFqmgxis92FY_stoXLoIw.jpg': ('single', 'pepperoni'),
    'AaFqmh-iN4-b6GejtTPp0A-AaFqmh-iK8OBWlv6C65xGg.jpg': ('single', 'mushroom'),
    'AaFqmhZHOtt_Y4zoWFlusQ-AaFqmhZH7VT4ZU_pR2T1Fg.jpg': ('single', 'chicken'),
    'AaFqmsUfdeKTAEkDTjhs8A-AaFqmsUfE8MxFMutNFvCmA.jpg': ('grid', [
        'bell_pepper_green', 'olive_black', 'onion', 'tomato',
        'basil', 'corn', 'ham', 'sausage']),
    'AaFqmu7xisoI5ZNQztntGw-AaFqmu7xAwLg3YOxC6vuCg.jpg': ('grid', [
        'bell_pepper_red', 'red_onion', 'cherry_tomato', 'garlic',
        'olive_green', 'pineapple', 'jalapeno', 'chili_red']),
    'AaFqmuKLUaEe870ssl3eww-AaFqmuKL-aGCH9SOp3_P8A.jpg': ('grid', [
        'cheddar', 'feta', 'parmesan', 'roumi',
        'bacon', 'ground_beef', 'tuna', 'blue_cheese']),
    'AaFqmvs_2Mw2WKRAVfLo_Q-AaFqmvs_FaKp9GOzrCKrHQ.jpg': ('grid', [
        'oregano', 'parsley', 'capers', 'artichoke',
        'shrimp', 'calamari', 'anchovy', 'salami_spicy']),
    # Same ingredient in 4 shape variants per row.
    'AaFqmw2MUfysZW5H30fwlQ-AaFqmw2MZt-Pib8AGaMrPg.jpg': ('grid', [
        'basterma', 'basterma', 'basterma', 'basterma',
        'mortadella', 'mortadella', 'mortadella', 'mortadella']),
}


def _main_components(mask: np.ndarray) -> np.ndarray:
    """Keep blobs >= 3% of the largest (drops bleed from neighbour cells),
    dilated slightly so soft edges survive."""
    from scipy import ndimage
    labels, n = ndimage.label(mask)
    if n == 0:
        return np.ones_like(mask, dtype=np.float32)
    sizes = ndimage.sum(mask, labels, range(1, n + 1))
    keep = np.isin(labels, 1 + np.flatnonzero(sizes >= sizes.max() * 0.03))
    return ndimage.binary_dilation(keep, iterations=3).astype(np.float32)


# Near-white items: neutral threshold must stay low or their bodies vanish
# (their drop shadow is kept; better source photos would fix that).
WHITE_ITEMS = {'onion', 'calamari', 'feta', 'mozzarella', 'mushroom', 'garlic'}


def cut_out(img: Image.Image, neutral_start: int = 26) -> Image.Image:
    """White background -> transparent, then crop to content."""
    a = np.asarray(img.convert('RGB')).astype(np.float32)
    dist = 255 - a.min(axis=2)  # 0 for pure white
    sat = a.max(axis=2) - a.min(axis=2)
    # Studio shadows are bright and neutral: demand more darkness from
    # low-saturation pixels so the drop shadow is dropped, colors are kept.
    start = np.where(sat < 10, neutral_start, 6)
    alpha = np.clip((dist - start) / 14, 0, 1)
    alpha *= _main_components(alpha > 0.5)
    # Un-premultiply the white halo from semi-transparent edge pixels.
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((a - 255 * (1 - alpha[..., None])) / safe, 0, 255)
    rgba = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    out = Image.fromarray(rgba, 'RGBA')
    bbox = out.getchannel('A').point(lambda v: 255 if v > 24 else 0).getbbox()
    return out.crop(bbox) if bbox else out


def pad_square(img: Image.Image, margin=0.04) -> Image.Image:
    side = int(max(img.size) * (1 + 2 * margin))
    canvas = Image.new('RGBA', (side, side))
    canvas.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    return canvas


def save_webp(img: Image.Image, path: Path, max_bytes: int) -> int:
    for q in (90, 85, 80, 70, 60):
        img.save(path, 'WEBP', quality=q, method=6)
        if path.stat().st_size <= max_bytes:
            return path.stat().st_size
    raise SystemExit(f'{path} exceeds {max_bytes} bytes even at q=60')


def save_ingredient(piece: Image.Image, name: str, counters: dict) -> None:
    counters[name] = counters.get(name, 0) + 1
    piece = cut_out(piece, 6 if name in WHITE_ITEMS else 26)
    piece.thumbnail((ING_MAX_SIDE, ING_MAX_SIDE), Image.LANCZOS)
    path = OUT / 'ingredients' / f'ing_{name}_{counters[name]:02d}.webp'
    size = save_webp(pad_square(piece, 0.02), path, ING_MAX_BYTES)
    print(f'{path}  {size // 1024}KB')


def main() -> None:
    (OUT / 'bases').mkdir(parents=True, exist_ok=True)
    (OUT / 'ingredients').mkdir(parents=True, exist_ok=True)
    counters: dict = {}
    for file, (kind, names) in SOURCES.items():
        img = Image.open(RAW / file)
        if kind == 'base':
            base = pad_square(cut_out(img), 0.01).resize(
                (BASE_SIDE, BASE_SIDE), Image.LANCZOS)
            path = OUT / 'bases' / f'{names}.webp'
            print(f'{path}  {save_webp(base, path, BASE_MAX_BYTES) // 1024}KB')
        elif kind == 'single':
            save_ingredient(img, names, counters)
        else:
            w, h = img.size
            cw, ch = w // 4, h // 2
            for i, name in enumerate(names):
                r, c = divmod(i, 4)
                save_ingredient(img.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)),
                                name, counters)


if __name__ == '__main__':
    os.chdir(Path(__file__).resolve().parent.parent)
    main()
