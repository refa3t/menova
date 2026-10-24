"""Convert the owner's procedural oven layers (oven_layers/, OVEN.md) into
compressed WebP animation assets under assets_src/animation/oven/.

Usage (from repo root): python tools/process_oven.py
Layers drawn in code (scrim, glow, vignette, flash) and the placeholder
pizzas are skipped. All frames keep the full square so they stay centred.
"""
import glob
import os
from pathlib import Path

from PIL import Image

SRC = Path('oven_layers')
OUT = Path('assets_src/animation/oven')
SIDE = 640
FILES = {
    'layer_02_hearth.png': 'oven_hearth',
    'layer_05_embers.png': 'oven_embers',
    'layer_08_steam.png': 'oven_steam',
    'layer_09_rim.png': 'oven_rim',
}


def save(src: Path, name: str) -> int:
    im = Image.open(src).convert('RGBA').resize((SIDE, SIDE), Image.LANCZOS)
    path = OUT / f'{name}.webp'
    im.save(path, 'WEBP', quality=78, method=6)
    return path.stat().st_size


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for f, name in FILES.items():
        total += save(SRC / f, name)
    for kind in ('back', 'front'):
        for f in sorted(glob.glob(str(SRC / f'frames_fire_{kind}' / '*.png'))):
            idx = Path(f).stem.split('_')[-1]
            total += save(Path(f), f'oven_fire_{kind}_{idx}')
    print(f'{len(list(OUT.glob("*.webp")))} files, {total // 1024}KB total')


if __name__ == '__main__':
    os.chdir(Path(__file__).resolve().parent.parent)
    main()
