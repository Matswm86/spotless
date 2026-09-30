"""Synthesises every sound in assets/audio: a calm music loop, seamless tool loops
(water spray, foam, scrubbing, grinder, spray paint, polisher, vacuum) and short effects.
Needs numpy, scipy and soundfile. No samples are used."""
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets/audio"
rng = np.random.default_rng(5)


def write(name: str, data: np.ndarray) -> None:
    if data.ndim == 1:
        data = np.stack([data, data], 1)
    data = data / (np.abs(data).max() + 1e-9) * 0.8
    path = OUT / f"{name}.ogg"
    with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(data), 4096):
            f.write(np.ascontiguousarray(data[i : i + 4096]))
    print(f"{name}: {path.stat().st_size // 1024} KB")


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def lp(x, hi, order=2):
    return sosfilt(butter(order, hi, "low", fs=SR, output="sos"), x)


def hp(x, lo, order=2):
    return sosfilt(butter(order, lo, "high", fs=SR, output="sos"), x)


def seamless(x: np.ndarray, fade: float = 0.25) -> np.ndarray:
    """Crossfade the tail into the head so the loop has no click."""
    n = int(fade * SR)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    w = np.linspace(0, 1, n)
    return np.concatenate([tail * (1 - w) + head * w, body])


def t_axis(sec: float) -> np.ndarray:
    return np.arange(int(sec * SR)) / SR


def noise(sec: float) -> np.ndarray:
    return rng.normal(0, 1, int(sec * SR))


# ---------- tool loops ----------
def spray():
    d = 3.5
    t = t_axis(d)
    x = bp(noise(d), 1200, 9000) * 0.9 + bp(noise(d), 90, 400) * 0.6
    x *= 1 + 0.12 * np.sin(2 * np.pi * 7 * t) + 0.08 * lp(noise(d), 4)
    for _ in range(90):  # droplets hitting the surface
        i = rng.integers(0, len(t) - 2000)
        f = rng.uniform(1800, 4200)
        tt = t_axis(0.03)
        x[i : i + len(tt)] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * 140) * 0.35
    return seamless(x)


def foam():
    d = 3.5
    t = t_axis(d)
    x = bp(noise(d), 2000, 8000) * 0.35 + bp(noise(d), 150, 600) * 0.25
    for _ in range(900):
        i = rng.integers(0, len(t) - 1500)
        f = rng.uniform(900, 3800)
        tt = t_axis(0.02)
        x[i : i + len(tt)] += np.sin(2 * np.pi * f * tt * (1 + tt * 20)) * np.exp(-tt * 260) * rng.uniform(0.2, 0.7)
    return seamless(x)


def scrub():
    d = 3.2
    t = t_axis(d)
    x = bp(noise(d), 500, 3800)
    stroke = np.abs(np.sin(2 * np.pi * 2.5 * t)) ** 0.6
    x *= 0.35 + 0.65 * stroke
    x += bp(noise(d), 3000, 7000) * 0.25 * stroke
    for _ in range(300):  # squeaky soap bubbles
        i = rng.integers(0, len(t) - 1500)
        tt = t_axis(0.015)
        x[i : i + len(tt)] += np.sin(2 * np.pi * rng.uniform(2000, 5000) * tt) * np.exp(-tt * 300) * 0.3
    return seamless(x)


def grind():
    d = 3.0
    t = t_axis(d)
    wob = 1 + 0.01 * np.sin(2 * np.pi * 3 * t)
    ph = 2 * np.pi * np.cumsum(1900 * wob) / SR
    x = 0.3 * np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.1 * np.sin(3.01 * ph)
    x += bp(noise(d), 2500, 9000) * 0.7
    x += bp(noise(d), 100, 300) * 0.3
    crack = (rng.random(len(t)) < 0.004) * rng.uniform(-1, 1, len(t))
    x += hp(crack, 3000) * 2.0
    return seamless(lp(x, 10000))


def paint():
    d = 3.0
    t = t_axis(d)
    x = hp(noise(d), 2800) * 0.8 + bp(noise(d), 600, 1600) * 0.15
    x *= 1 + 0.05 * np.sin(2 * np.pi * 11 * t)
    return seamless(lp(x, 12000))


def polish():
    d = 3.0
    t = t_axis(d)
    ph = 2 * np.pi * 118 * t
    x = 0.35 * np.sin(ph) + 0.2 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)
    x += bp(noise(d), 300, 1400) * 0.55 * (0.7 + 0.3 * np.abs(np.sin(2 * np.pi * 4 * t)))
    x += bp(noise(d), 3000, 6000) * 0.1
    return seamless(x)


def vacuum():
    d = 3.0
    t = t_axis(d)
    ph = 2 * np.pi * np.cumsum(620 * (1 + 0.004 * np.sin(2 * np.pi * 1.3 * t))) / SR
    x = 0.12 * np.sin(ph) + 0.06 * np.sin(2 * ph) + 0.04 * np.sin(5 * ph)
    x += lp(noise(d), 3500) * 0.5 + bp(noise(d), 150, 500) * 0.4
    for _ in range(120):  # dust ticking up the tube
        i = rng.integers(0, len(t) - 800)
        tt = t_axis(0.008)
        x[i : i + len(tt)] += rng.uniform(-1, 1, len(tt)) * np.exp(-tt * 600) * 0.6
    return seamless(x)


# ---------- one-shots ----------
def env(sec, attack=0.005, decay=8.0):
    t = t_axis(sec)
    return np.minimum(1, t / attack) * np.exp(-t * decay)


def bell(f, sec=1.6, decay=3.0):
    t = t_axis(sec)
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2.76 * f * t) * np.exp(-t * 4) + 0.2 * np.sin(2 * np.pi * 5.4 * f * t) * np.exp(-t * 8)
    return x * env(sec, 0.003, decay)


def place(buf, start, sig, gain=1.0):
    i = int(start * SR)
    buf[i : i + len(sig)] += sig[: max(0, len(buf) - i)] * gain


def tap():
    t = t_axis(0.09)
    return np.sin(2 * np.pi * 1400 * t * (1 - t * 3)) * env(0.09, 0.001, 60) + hp(noise(0.09), 3000) * env(0.09, 0.001, 120) * 0.3


def pop():
    t = t_axis(0.18)
    return np.sin(2 * np.pi * (500 + 1400 * np.exp(-t * 30)) * t) * env(0.18, 0.001, 22)


def toss():
    d = 0.6
    t = t_axis(d)
    w = bp(noise(d), 500, 3000) * np.sin(np.pi * np.clip(t / 0.4, 0, 1)) ** 2 * 0.4
    thud = np.sin(2 * np.pi * 110 * t) * np.exp(-np.maximum(t - 0.42, 0) * 25) * (t > 0.42)
    thud += bp(noise(d), 200, 1500) * np.exp(-np.maximum(t - 0.42, 0) * 40) * (t > 0.42) * 0.5
    return w + thud * 0.8


def swoosh():
    d = 0.45
    t = t_axis(d)
    return bp(noise(d), 800, 5000) * np.sin(np.pi * t / d) ** 2


def stage():
    x = np.zeros(int(1.8 * SR))
    place(x, 0.0, bell(784, 1.5), 0.6)
    place(x, 0.12, bell(1175, 1.5), 0.6)
    return x


def win():
    x = np.zeros(int(3.0 * SR))
    for k, m in enumerate([72, 76, 79, 84, 88]):
        f = 440 * 2 ** ((m - 69) / 12)
        place(x, k * 0.11, bell(f, 2.2, 2.2), 0.5)
    shimmer = hp(noise(2.5), 6000) * env(2.5, 0.3, 2.0) * 0.08
    place(x, 0.3, shimmer)
    return x


def sparkle():
    x = np.zeros(int(1.4 * SR))
    for k in range(9):
        f = 2000 + k * 260 + rng.uniform(-80, 80)
        place(x, k * 0.05 + rng.uniform(0, 0.02), bell(f, 0.6, 9.0), 0.3)
    return x


# ---------- music ----------
def music():
    bpm = 68
    beat = 60 / bpm
    bars = 16
    dur = bars * 4 * beat
    n = int(dur * SR)
    L = np.zeros(n)
    R = np.zeros(n)

    def hz(m):
        return 440 * 2 ** ((m - 69) / 12)

    def add(buf, start, sig, g=1.0):
        i = int(start * SR) % n
        j = min(n, i + len(sig))
        buf[i:j] += sig[: j - i] * g
        rest = len(sig) - (j - i)
        if rest > 0:
            buf[:rest] += sig[j - i :] * g

    def rhodes(m, length, vel):
        t = t_axis(length + 2.0)
        f = hz(m)
        x = np.sin(2 * np.pi * f * t + 0.6 * np.sin(2 * np.pi * f * t) * np.exp(-t * 4))
        x += 0.15 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 2)
        x *= 1 + 0.05 * np.sin(2 * np.pi * 5 * t)
        return x * np.minimum(1, t * 300) * np.exp(-t * 1.4) * vel

    def pad(ms, length, vel):
        t = t_axis(length + 1.5)
        e = np.minimum(1, t / 1.5) * np.clip((length + 1.5 - t) / 1.5, 0, 1)
        x = np.zeros_like(t)
        for m in ms:
            for det in (-0.1, 0.1):
                f = hz(m + det)
                x += np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * 2 * f * t)
        return lp(x, 2500) * e * vel / len(ms)

    # Fmaj7 - Dm9 - Bbmaj7 - C6/9, two bars each, twice
    chords = [[41, 48, 52, 57, 64], [38, 50, 53, 57, 64], [34, 46, 50, 57, 62], [36, 48, 52, 57, 62]]
    scale = [65, 67, 69, 72, 74, 76, 77, 79]
    for rep in range(2):
        for ci, ch in enumerate(chords):
            s = (rep * 8 + ci * 2) * 4 * beat
            p = pad(ch[1:], 8 * beat, 0.16)
            add(L, s, p, 0.95)
            add(R, s, p, 1.0)
            for bb in (0, 4):
                b = rhodes(ch[0], 3, 0.3)
                add(L, s + bb * beat, b)
                add(R, s + bb * beat, b)
            for k, bt in enumerate([0.5, 2, 3.5, 4.5, 6, 7]):
                m = ch[1 + (k % 4)] + 12
                x = rhodes(m, 1.2, 0.12)
                pan = 0.3 + 0.4 * (k % 2)
                add(L, s + bt * beat, x, 1 - pan)
                add(R, s + bt * beat, x, pan)
    # music-box melody, sparse
    for b in range(bars * 4):
        if (b % 2 == 0 and rng.random() < 0.45) or rng.random() < 0.1:
            m = int(rng.choice(scale)) + 12
            x = bell(hz(m), 2.0, 2.4) * 0.12
            pan = rng.uniform(0.3, 0.7)
            add(L, b * beat, x, 1 - pan)
            add(R, b * beat, x, pan)
    # gentle water-drop texture
    for _ in range(40):
        s = rng.uniform(0, dur)
        f = rng.uniform(900, 1600)
        tt = t_axis(0.12)
        x = np.sin(2 * np.pi * f * tt * (1 + tt * 6)) * np.exp(-tt * 45) * 0.05
        pan = rng.uniform(0.2, 0.8)
        add(L, s, x, 1 - pan)
        add(R, s, x, pan)

    def reverb(x):
        t = t_axis(2.2)
        ir = rng.normal(0, 1, len(t)) * np.exp(-t * 2.6)
        ir[0] = 0
        y = fftconvolve(x, ir)
        out = y[:n].copy()
        out[: len(y) - n] += y[n:]
        return out

    L2 = L + 0.04 * reverb(L)
    R2 = R + 0.04 * reverb(R)
    return np.stack([lp(L2, 6000), lp(R2, 6000)], 1) * 0.9


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in [("spray", spray), ("foam", foam), ("scrub", scrub), ("grind", grind), ("paint", paint),
                     ("polish", polish), ("vacuum", vacuum), ("tap", tap), ("pop", pop), ("toss", toss),
                     ("swoosh", swoosh), ("stage", stage), ("win", win), ("sparkle", sparkle), ("music", music)]:
        write(name, fn())
