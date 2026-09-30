"""Tileable noise texture for the dirt shader (assets/tex/noise.png).

R = large blotches, G = medium patches, B = fine grain, A = soap-bubble cells.
Every channel tiles because it is built in the frequency domain or on a wrapped grid.
"""
from pathlib import Path

import numpy as np
from PIL import Image

N = 512
rng = np.random.default_rng(11)


def fbm(base_freq: float, octaves: int, falloff: float = 0.55) -> np.ndarray:
    fx = np.fft.fftfreq(N)[:, None] * N
    fy = np.fft.fftfreq(N)[None, :] * N
    f = np.sqrt(fx**2 + fy**2)
    out = np.zeros((N, N))
    amp = 1.0
    freq = base_freq
    for _ in range(octaves):
        band = np.exp(-(((f - freq) / (freq * 0.6)) ** 2))
        spec = (rng.normal(size=(N, N)) + 1j * rng.normal(size=(N, N))) * band
        layer = np.real(np.fft.ifft2(spec))
        out += amp * layer / (np.abs(layer).max() + 1e-9)
        amp *= falloff
        freq *= 2.1
    out -= out.min()
    return out / out.max()


def bubbles(cells: int) -> np.ndarray:
    """Worley distance on a wrapped grid, inverted so bubble centres are bright."""
    pts = (np.arange(cells)[:, None, None] + rng.random((cells, cells, 2))) / cells
    yy, xx = np.mgrid[0:N, 0:N] / N
    best = np.full((N, N), 9.0)
    step = 1.0 / cells
    for i in range(cells):
        for j in range(cells):
            px, py = (j + rng.random()) * step, (i + rng.random()) * step
            dx = np.abs(xx - px)
            dy = np.abs(yy - py)
            dx = np.minimum(dx, 1 - dx)
            dy = np.minimum(dy, 1 - dy)
            best = np.minimum(best, np.sqrt(dx * dx + dy * dy))
    b = 1 - np.clip(best / step, 0, 1)
    return b**1.6


r = fbm(3, 4)
g = fbm(6, 4)
b = fbm(28, 3, 0.7)
a = bubbles(24)
img = np.stack([r, g, b, a], -1)
img = (img * 255).astype(np.uint8)
out = Path(__file__).resolve().parent.parent / "assets/tex/noise.png"
Image.fromarray(img, "RGBA").save(out, optimize=True)
print(out, out.stat().st_size)
