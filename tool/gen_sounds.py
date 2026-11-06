"""Procedurally synthesizes the abacus impact sounds (modal synthesis).

Run:  python3 tool/gen_sounds.py   -> writes assets/sounds/*.wav

bone_*: bead hits bead. A soft, rounded wooden "tok": a ~1 ms contact pulse
        (which naturally rolls off the harsh highs) exciting a few mid
        resonances that die out within a few milliseconds.
wood_*: bead hits the wooden frame. A deeper, hollow knock of the frame bar
        with a little of the bead's own "tok" on top.
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
rng = np.random.default_rng(11)


def pulse(ms):
    n = max(2, int(SR * ms / 1000))
    return 0.5 - 0.5 * np.cos(2 * np.pi * np.arange(n) / n)  # raised cosine


def modal(dur, contact_ms, modes, noise=0.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f, decay, amp in modes:
        f *= 1 + rng.uniform(-0.05, 0.05)
        out += amp * np.sin(2 * np.pi * f * t) * np.exp(-t / decay)
    if noise:
        out += noise * rng.standard_normal(n) * np.exp(-t / 0.002)
    out = np.convolve(out, pulse(contact_ms))[:n]
    return out


def lowpass(s, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(s)
    acc = 0.0
    for i, x in enumerate(s):
        acc = (1 - a) * x + a * acc
        y[i] = acc
    return y


def bead(v):
    s = modal(0.08, 0.9 + 0.15 * v, [
        (1250, 0.010, 0.6),
        (2150, 0.006, 1.0),
        (3300, 0.004, 0.55),
        (4600, 0.0025, 0.25),
    ], noise=0.05)
    return lowpass(s, 5000)


def frame(v):
    s = modal(0.2, 1.6 + 0.2 * v, [
        (190, 0.045, 0.7),
        (360, 0.032, 1.0),
        (640, 0.020, 0.7),
        (1080, 0.012, 0.45),
        (1700, 0.007, 0.25),
    ], noise=0.03)
    b = bead(v)
    s[: len(b)] += 0.25 * b / np.max(np.abs(b)) * np.max(np.abs(s))
    return lowpass(s, 3500)


def write(name, s, peak):
    s = s - s.mean()
    s = s / np.max(np.abs(s)) * peak
    fade = int(SR * 0.01)
    s[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((s * 32767).astype('<i2').tobytes())


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for i in range(4):
        write(f'bone_{i}.wav', bead(i), 0.5)
        write(f'wood_{i}.wav', frame(i), 0.55)
    print('ok')
