"""Synthesizes the reward and the "oh no" cues for the exercises.

success.wav: a soft wooden marimba arpeggio going up (C E G C).
fail.wav: two sad notes sliding down, like a gentle "wah-wah".
"""
import numpy as np
import wave

SR = 44100


def marimba(freq, dur, amp):
    t = np.arange(int(SR * dur)) / SR
    # Marimba bars: fundamental plus a quiet 4th partial that dies fast.
    s = np.sin(2 * np.pi * freq * t) * np.exp(-t * 5)
    s += 0.25 * np.sin(2 * np.pi * freq * 3.9 * t) * np.exp(-t * 18)
    s += 0.1 * np.sin(2 * np.pi * freq * 9.2 * t) * np.exp(-t * 40)
    attack = np.minimum(1, t / 0.004)
    return amp * s * attack


def mix(parts, total):
    out = np.zeros(int(SR * total))
    for start, sig in parts:
        i = int(SR * start)
        n = min(len(sig), len(out) - i)
        out[i:i + n] += sig[:n]
    return out


def save(name, sig):
    sig = sig / np.max(np.abs(sig)) * 0.8
    data = (sig * 32767).astype(np.int16)
    with wave.open(f'assets/sounds/{name}', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def sad(f0, f1, dur):
    t = np.arange(int(SR * dur)) / SR
    f = f0 + (f1 - f0) * np.clip(t / dur, 0, 1) ** 1.5
    f = f * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    # A muted, slightly nasal tone: odd harmonics, soft envelope.
    s = np.sin(phase) + 0.3 * np.sin(3 * phase) + 0.12 * np.sin(5 * phase)
    env = np.minimum(1, t / 0.03) * np.exp(-t * 1.6)
    env *= np.minimum(1, (dur - t) / 0.08)
    return s * env


notes = [523.25, 659.25, 783.99, 1046.5]
save('success.wav', mix(
    [(i * 0.11, marimba(f, 1.2, 1.0 - 0.1 * i)) for i, f in enumerate(notes)]
    + [(0.33, marimba(1318.5, 1.0, 0.35))],
    1.6,
))
save('fail.wav', mix([(0, sad(392, 370, 0.42)), (0.45, sad(349, 294, 0.9))], 1.4))
