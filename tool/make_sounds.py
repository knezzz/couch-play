#!/usr/bin/env python3
"""Synthesises the TV's short sound effects into apps/tv/assets/sounds/*.wav.

Self-made (sine and noise, standard library only), so there is no licence to
carry. Run it from anywhere: python3 tool/make_sounds.py. The output is
committed; the names match the Sound enum in apps/tv/lib/sound/sfx.dart.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
PEAK = 0.35  # quiet: these play often
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'apps', 'tv', 'assets', 'sounds')


def tone(freq, dur, shape='sine', slide=None):
    """freq Hz (or start of a slide to `slide` Hz), dur seconds, fade in/out."""
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq if slide is None else freq + (slide - freq) * i / n
        phase += 2 * math.pi * f / RATE
        v = math.sin(phase)
        if shape == 'square':
            v = 1.0 if v >= 0 else -1.0
            v *= 0.6
        fade = min(1.0, i / (RATE * 0.005), (n - i) / (RATE * 0.03))
        out.append(v * fade)
    return out


def noise(dur, decay=6.0):
    rnd = random.Random(1)  # same file every run
    n = int(RATE * dur)
    return [(rnd.random() * 2 - 1) * math.exp(-decay * i / n) for i in range(n)]


def mix(a, b):
    n = max(len(a), len(b))
    return [(a[i] if i < len(a) else 0) + (b[i] if i < len(b) else 0) for i in range(n)]


def seq(*parts):
    out = []
    for p in parts:
        out += p
    return out


def gap(dur):
    return [0.0] * int(RATE * dur)


N = {'C4': 261.63, 'E4': 329.63, 'G4': 392.0, 'A4': 440.0, 'C5': 523.25, 'E5': 659.25, 'G5': 783.99, 'C6': 1046.5}

SOUNDS = {
    'join': seq(tone(660, 0.06), tone(880, 0.08)),
    'countdownBeep': tone(440, 0.12),
    'countdownGo': tone(880, 0.3),
    'pickup': tone(600, 0.12, slide=1200),
    'crash': mix(noise(0.25), tone(220, 0.25, slide=70)),
    'roundWin': seq(tone(N['C5'], 0.1), tone(N['E5'], 0.1), tone(N['G5'], 0.2)),
    'matchWin': seq(tone(N['C5'], 0.12), tone(N['E5'], 0.12), tone(N['G5'], 0.12), tone(N['C6'], 0.4)),
    'quizStart': seq(tone(N['C5'], 0.08), tone(N['E5'], 0.12)),
    'tick': tone(1000, 0.04),
    'right': seq(tone(N['E5'], 0.1), tone(N['A4'] * 2.25, 0.2)),
    'wrong': tone(200, 0.3, shape='square', slide=140),
    'fanfare': seq(tone(N['C5'], 0.15), tone(N['C5'], 0.15), tone(N['G5'], 0.15), tone(N['E5'], 0.1),
                   tone(N['G5'], 0.1), gap(0.05), tone(N['C6'], 0.5)),
}


def write(name, samples):
    path = os.path.join(OUT, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * PEAK)) * 32767)) for s in samples))
    return os.path.getsize(path)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name, samples in SOUNDS.items():
        print(f'{name}.wav {write(name, samples)} bytes, {len(samples) / RATE:.2f} s')
