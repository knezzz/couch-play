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


def env(samples, decay):
    """Exponential decay over the whole sound (percussive)."""
    n = len(samples)
    return [s * math.exp(-decay * i / n) for i, s in enumerate(samples)]


def voice(contour, harmonics=(1.0,), vibrato=0.0, attack=0.01, release=0.05, rate=RATE):
    """A pitched voice following contour [(freq, seconds), ...] (linear glides between points)."""
    out, phase = [], 0.0
    total = sum(d for _, d in contour)
    t = 0.0
    for k, (f0, d) in enumerate(contour):
        f1 = contour[k + 1][0] if k + 1 < len(contour) else f0
        n = int(rate * d)
        for i in range(n):
            f = f0 + (f1 - f0) * i / n
            f *= 1 + vibrato * math.sin(2 * math.pi * 5.5 * t)
            phase += 2 * math.pi * f / rate
            v = sum(a * math.sin(h * phase) for h, a in enumerate(harmonics, 1)) / sum(harmonics)
            fade = min(1.0, t / attack, (total - t) / release)
            out.append(v * fade)
            t += 1 / rate
    return out


def bell(freq, dur):
    """Inharmonic partials with their own decays: a small hand bell."""
    n = int(RATE * dur)
    parts = ((1.0, 1.0, 3.0), (2.76, 0.5, 5.0), (5.4, 0.25, 8.0), (8.93, 0.12, 12.0))
    return [sum(a * math.sin(2 * math.pi * freq * r * i / RATE) * math.exp(-k * i / RATE) for r, a, k in parts) / 1.87
            * min(1.0, i / (RATE * 0.002)) for i in range(n)]


AMB_RATE = 11025  # the ambience is all low sound, so half the rate keeps it small


def night(dur=8.0):
    """Night pad: a low A drone (two detuned A2s, E3, A3) that swells in and out, with soft wind noise."""
    rnd = random.Random(2)
    n = int(AMB_RATE * dur)
    out, lp = [], 0.0
    for i in range(n):
        t = i / AMB_RATE
        pad = (math.sin(2 * math.pi * 110 * t) + math.sin(2 * math.pi * 110.6 * t)
               + 0.6 * math.sin(2 * math.pi * 164.8 * t) + 0.3 * math.sin(2 * math.pi * 220.3 * t)) / 2.9
        lp += 0.02 * ((rnd.random() * 2 - 1) - lp)  # one-pole low-pass: a dull whoosh
        wind = lp * 4 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.25 * t))
        fade = min(1.0, t / 2.0, (dur - t) / 3.0)
        out.append((0.8 * pad + 0.4 * wind) * fade)
    return out


def drum(dur=0.6):
    """Low tom: a pitch drop 110 -> 55 Hz with a fast decay, plus a short noise slap."""
    body = env(tone(110, dur, slide=55), 7.0)
    return mix(body, [s * 0.35 for s in noise(0.05, decay=10.0)])


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
    # Task 32
    'menuMove': env(tone(1400, 0.04), 4.0),
    'menuConfirm': seq(tone(N['E5'], 0.05), tone(N['A4'] * 2, 0.08)),
    'quizTick': env(tone(700, 0.05), 6.0),  # soft every-second tock; tick.wav stays the sharper last-5-s one
    'nightAmbience': night(),
    'howl': voice([(330, 0.35), (520, 0.9), (500, 0.35), (380, 0.01)], harmonics=(1.0, 0.25, 0.08),
                  vibrato=0.012, attack=0.25, release=0.4, rate=AMB_RATE),
    'rooster': seq(voice([(520, 0.12), (700, 0.01)], harmonics=(1.0, 0.6, 0.4, 0.2)), gap(0.03),
                   voice([(700, 0.12), (760, 0.01)], harmonics=(1.0, 0.6, 0.4, 0.2)), gap(0.03),
                   voice([(780, 0.45), (900, 0.15), (640, 0.01)], harmonics=(1.0, 0.6, 0.4, 0.2), vibrato=0.01,
                         release=0.15)),
    'voteBell': bell(988, 1.2),
    'drum': drum(),
}
GAIN = {'menuMove': 0.8, 'quizTick': 0.8, 'nightAmbience': 0.7}  # quieter than PEAK: frequent or long
RATES = {'nightAmbience': AMB_RATE, 'howl': AMB_RATE}


def write(name, samples):
    path = os.path.join(OUT, name + '.wav')
    peak = PEAK * GAIN.get(name, 1.0)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATES.get(name, RATE))
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * peak)) * 32767)) for s in samples))
    return os.path.getsize(path)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name, samples in SOUNDS.items():
        print(f'{name}.wav {write(name, samples)} bytes, {len(samples) / RATES.get(name, RATE):.2f} s')
