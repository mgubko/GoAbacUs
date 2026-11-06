"""Procedurally synthesizes the abacus impact sounds (modal synthesis).

Run:  python3 tool/gen_sounds.py   -> writes assets/sounds/*.wav

bone_*: bead hits bead (solid hardwood). A dull "tock": a ~1.5 ms contact
        pulse exciting low-mid resonances that die within a few ms.
wood_*: bead hits the solid frame bar: a lower, damped knock with a little
        of the bead's own "tock" on top.
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
    # Solid hardwood bead on bead: short, dull "tock", no ringing.
    s = modal(0.06, 1.4 + 0.2 * v, [
        (680, 0.0055, 0.8),
        (1180, 0.0040, 1.0),
        (1900, 0.0026, 0.5),
        (2900, 0.0016, 0.2),
    ], noise=0.02)
    return lowpass(lowpass(s, 2800), 2800)


def frame(v):
    # Bead on the solid frame bar: lower and a little longer, still damped.
    s = modal(0.12, 2.0 + 0.25 * v, [
        (160, 0.022, 0.7),
        (300, 0.016, 1.0),
        (540, 0.011, 0.7),
        (880, 0.007, 0.4),
        (1350, 0.004, 0.2),
    ], noise=0.015)
    b = bead(v)
    s[: len(b)] += 0.3 * b / np.max(np.abs(b)) * np.max(np.abs(s))
    return lowpass(lowpass(s, 2200), 2200)


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
