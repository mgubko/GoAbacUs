"""Cuts single bead clicks out of a recording of a real wooden abacus.

Usage:  ffmpeg -i recording.mp3 -ac 1 -ar 44100 src.wav
        python3 tool/cut_sounds.py src.wav

Writes assets/sounds/bone_*.wav (bead hits bead) and wood_*.wav (beads hit
the frame). The onset times below were picked from the reference recording
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
FRAME = [0.707, 2.054, 3.505, 5.510]


def cut(x, sr, t, length):
    st = int((t - 0.002) * sr)
    seg = x[st:st + int(sr * length)].copy()
    seg -= seg.mean()
    fi = int(sr * 0.001)
    seg[:fi] *= np.linspace(0, 1, fi)
    fo = int(len(seg) * 0.35)
    seg[-fo:] *= np.linspace(1, 0, fo) ** 2
    return seg


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
    for i, t in enumerate(FRAME):
        write(f'wood_{i}.wav', cut(x, sr, t, 0.14), sr, 0.55)
    print('ok')
