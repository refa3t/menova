"""Synthesize the reception's new-order chime (ASSETS.md 4.5).

A rising three-note bell (A5, C#6, E6) played twice: each note is a
fundamental plus the inharmonic partials of a struck metal bar
(glockenspiel), with a fast attack and an exponential decay (higher
partials die faster). Mono, 44.1 kHz, peak normalized to -1 dBFS, written
as MP3 (plays in Chrome, Safari iOS and Firefox), under 3 s and 100 KB.

Deterministic: the partial phases come from a fixed seed, and LAME output
is stable for the same input and settings.

Needs numpy and lameenc (`pip install lameenc`, bundles LAME).
Run from the repository root:
    python tools/make_order_sound.py
Output: apps/reception/web/sounds/sfx_new_order.mp3
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

RATE = 44_100
SEED = 45
PEAK_DBFS = -1.0
BITRATE_KBPS = 96

# Rising A-major arpeggio; the motif repeats after a short gap.
NOTES_HZ = (880.0, 1108.73, 1318.51)
NOTE_STEP_S = 0.10
REPEAT_AT_S = 0.62
TOTAL_S = 1.6
FADE_OUT_S = 0.25

# Free-bar partials: (frequency ratio, relative amplitude, decay factor).
PARTIALS = (
    (1.000, 1.00, 1.00),
    (2.756, 0.32, 0.45),
    (5.404, 0.12, 0.25),
    (8.933, 0.04, 0.15),
)
DECAY_S = 0.32  # time constant of the fundamental
ATTACK_S = 0.003

OUT = Path("apps/reception/web/sounds/sfx_new_order.mp3")


def bell(freq: float, rng: np.random.Generator) -> np.ndarray:
    """One struck note, long enough to reach the end of the file."""
    t = np.arange(int(TOTAL_S * RATE)) / RATE
    note = np.zeros_like(t)
    for ratio, amp, decay in PARTIALS:
        f = freq * ratio
        if f >= RATE / 2 * 0.9:
            continue
        phase = rng.uniform(0, 2 * np.pi)
        note += amp * np.exp(-t / (DECAY_S * decay)) * np.sin(2 * np.pi * f * t + phase)
    attack = np.minimum(t / ATTACK_S, 1.0)
    return note * (0.5 - 0.5 * np.cos(np.pi * attack))


def chime() -> np.ndarray:
    rng = np.random.default_rng(SEED)
    n = int(TOTAL_S * RATE)
    out = np.zeros(n)
    for start in (0.0, REPEAT_AT_S):
        for i, freq in enumerate(NOTES_HZ):
            onset = int((start + i * NOTE_STEP_S) * RATE)
            out[onset:] += bell(freq, rng)[: n - onset]
    fade = int(FADE_OUT_S * RATE)
    out[-fade:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, fade))
    return out * (10 ** (PEAK_DBFS / 20) / np.max(np.abs(out)))


def encode_mp3(samples: np.ndarray) -> bytes:
    import lameenc

    pcm = np.round(samples * 32767).astype("<i2")
    enc = lameenc.Encoder()
    enc.set_bit_rate(BITRATE_KBPS)
    enc.set_in_sample_rate(RATE)
    enc.set_channels(1)
    enc.set_quality(2)
    return bytes(enc.encode(pcm.tobytes()) + enc.flush())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    samples = chime()
    peak = np.max(np.abs(samples))
    assert peak < 1.0, "clipping"
    data = encode_mp3(samples)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(data)
    print(
        f"{args.out}: {len(samples) / RATE:.2f} s, peak "
        f"{20 * np.log10(peak):.2f} dBFS, {len(data) / 1024:.1f} KB MP3 "
        f"({BITRATE_KBPS} kbps mono {RATE} Hz)"
    )


if __name__ == "__main__":
    main()
