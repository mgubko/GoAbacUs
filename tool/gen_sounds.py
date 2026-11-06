"""Procedurally synthesizes the abacus impact sounds (modal synthesis).

Run:  python3 tool/gen_sounds.py   -> writes assets/sounds/*.wav
Bone-on-bone: a very short broadband contact transient + a few high, quickly
decaying modes (hard, dense material). Bone-on-wood: a softer transient plus
lower, longer wooden body modes of the frame.
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
rng = np.random.default_rng(7)


def contact(n_ms, dur):
    """Half-sine contact force pulse filtered noise: the 'tick'."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    pulse_len = int(SR * n_ms / 1000)
    pulse = np.zeros(n)
    pulse[:pulse_len] = np.sin(np.pi * np.arange(pulse_len) / pulse_len)
    noise = rng.standard_normal(n) * np.exp(-t / 0.0015)
    return pulse, noise, t


def modes(t, pulse, spec):
    out = np.zeros_like(t)
    for f, decay, amp in spec:
        f *= 1 + rng.uniform(-0.04, 0.04)
        ring = amp * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / decay)
        out += np.convolve(pulse, ring)[: len(t)] / max(1, pulse.sum())
    return out


def bone(variant):
    pulse, noise, t = contact(0.35 + 0.1 * variant, 0.12)
    spec = [(2650, 0.010, 1.0), (4100, 0.007, 0.8), (5900, 0.005, 0.55),
            (7600, 0.004, 0.35), (1500, 0.014, 0.35), (9800, 0.003, 0.2)]
    s = modes(t, pulse, spec) + 0.35 * noise
    return s


def wood(variant):
    pulse, noise, t = contact(0.8 + 0.2 * variant, 0.25)
    spec = [(420, 0.045, 1.0), (760, 0.030, 0.8), (1180, 0.022, 0.6),
            (1850, 0.012, 0.45), (2900, 0.006, 0.35), (230, 0.06, 0.4)]
    s = modes(t, pulse, spec) + 0.25 * noise
    # bead's own click on top of the wooden knock
    click = bone(variant)
    s[: len(click)] += 0.35 * click
    return s


def write(name, s):
    s = s - s.mean()
    s = s / np.max(np.abs(s)) * 0.9
    fade = int(SR * 0.01)
    s[-fade:] *= np.linspace(1, 0, fade)
    data = (s * 32767).astype('<i2').tobytes()
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for i in range(4):
        write(f'bone_{i}.wav', bone(i))
        write(f'wood_{i}.wav', wood(i))
    print('ok')
