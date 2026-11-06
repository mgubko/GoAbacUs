"""Cuts single bead clicks out of a recording of a real wooden abacus.

Usage:  ffmpeg -i recording.mp3 -ac 1 -ar 44100 src.wav
        python3 tool/cut_sounds.py src.wav

Writes assets/sounds/bone_*.wav (bead hits bead), wood_*.wav (beads hit
the frame), and two seamless loops: slide.wav (one bead sliding on the wire)
and rattle.wav (a group sliding together, lightly knocking). The onset times below were picked from the reference recording
Mikhail supplied (2026-11-06): isolated clicks with no other hit within
~140 ms. The first seconds of that recording hold the heavier group hits,
used for the frame.
"""
import os
import sys
import wave

import numpy as np

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
BEAD = [9.014, 13.574, 16.279, 24.845]
# (onset, low-pass Hz or None). 2.054 was too sharp and loud (Mikhail picked
# it out, 2026-11-06); replaced by a softened 23.810.
FRAME = [(0.707, None), (23.810, 3500), (3.505, None), (5.510, None)]


def cut(x, sr, t, length):
    st = int((t - 0.002) * sr)
    seg = x[st:st + int(sr * length)].copy()
    seg -= seg.mean()
    fi = int(sr * 0.001)
    seg[:fi] *= np.linspace(0, 1, fi)
    fo = int(len(seg) * 0.35)
    seg[-fo:] *= np.linspace(1, 0, fo) ** 2
    return seg


def lowpass(s, sr, hz):
    a = np.exp(-2 * np.pi * hz / sr)
    y = np.zeros_like(s)
    acc = 0.0
    for i, v in enumerate(s):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def loop(s, sr, fade=0.25):
    # Seamless loop: cross-fade the tail into the head.
    n = int(sr * fade)
    head, body, tail = s[:n], s[n:-n], s[-n:]
    ramp = np.linspace(0, 1, n)
    return np.concatenate([body, tail * (1 - ramp) + head * ramp])


def slide_loop(sr, seconds=2.5, seed=3):
    # A wooden bead sliding on a steel wire: soft band-limited friction noise
    # with an irregular grain from the wire's roughness.
    rng = np.random.default_rng(seed)
    n = int(sr * (seconds + 0.25))
    noise = rng.standard_normal(n)
    band = lowpass(noise, sr, 2200) - lowpass(noise, sr, 500)
    grain = lowpass(np.abs(rng.standard_normal(n)), sr, 14)
    grain = 0.55 + 0.45 * grain / grain.max()
    return loop(band * grain, sr)


def rattle_loop(x, sr, seconds=2.5, seed=5, rate=28):
    # A group sliding together: the slide plus beads lightly knocking into
    # each other, a quick irregular patter of tiny clicks.
    rng = np.random.default_rng(seed)
    out = 0.6 * slide_loop(sr, seconds, seed + 1)
    out /= np.max(np.abs(out))
    clicks = [cut(x, sr, t, 0.05) for t in BEAD]
    clicks = [c / np.max(np.abs(c)) for c in clicks]
    t = 0.0
    while True:
        t += rng.exponential(1 / rate)
        i = int(t * sr)
        if i >= len(out) - int(sr * 0.05):
            break
        c = clicks[rng.integers(len(clicks))] * rng.uniform(0.15, 0.45)
        out[i:i + len(c)] += c
    return out


def write(name, s, sr, peak):
    s = s / np.max(np.abs(s)) * peak
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((s * 32767).astype('<i2').tobytes())


if __name__ == '__main__':
    with wave.open(sys.argv[1]) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), '<i2').astype(float) / 32767
    for i, t in enumerate(BEAD):
        write(f'bone_{i}.wav', cut(x, sr, t, 0.12), sr, 0.5)
    for i, (t, lp) in enumerate(FRAME):
        s = cut(x, sr, t, 0.14)
        if lp:
            s = lowpass(s, sr, lp)
        write(f'wood_{i}.wav', s, sr, 0.5 if lp else 0.55)
    write('slide.wav', slide_loop(sr), sr, 0.35)
    write('rattle.wav', rattle_loop(x, sr), sr, 0.4)
    print('ok')
