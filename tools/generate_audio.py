"""Surprise Games için özgün müzik ve ses efektlerini sıfırdan üretir.

Tüm sesler bu betikte matematiksel olarak sentezlenir; hiçbir sample, kayıt ya da
üçüncü taraf eser kullanılmaz. Bu yüzden telif / lisans sorunu yoktur.

Kullanım:  python tools/generate_audio.py   (numpy + scipy gerekir)
Çıktı:     assets/audio/music.wav, correct.wav, wrong.wav, over.wav
"""
import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import fftconvolve

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def env_adsr(n, a, d, s, r):
    t = np.arange(n) / SR
    e = np.ones(n) * s
    ai, di = int(a * SR), int(d * SR)
    if ai > 0:
        e[:ai] = np.linspace(0, 1, ai)
    if di > 0:
        e[ai:ai + di] = np.linspace(1, s, di)
    ri = int(r * SR)
    if ri > 0:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def add(buf, start_s, sig):
    i = int(start_s * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[: j - i]


def pad_note(midi, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    sig = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.004 * t)
           + 0.25 * np.sin(2 * np.pi * f * 2 * t))
    return sig * env_adsr(n, 0.5, 0.3, 0.8, 0.9) * 0.5


def pluck(midi, dur=0.9):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    sig = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 9)
    return sig * np.exp(-t * 5.5) * np.minimum(1, t * 300)


def bell(midi, dur=1.4):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    sig = (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 6)
           + 0.2 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 10))
    return sig * np.exp(-t * 3.2) * np.minimum(1, t * 500)


def bass_note(midi, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * hz(midi) * t) + 0.2 * np.sin(2 * np.pi * hz(midi) * 2 * t)
    return sig * env_adsr(n, 0.03, 0.2, 0.7, 0.3)


def kick(dur=0.35):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 120 * np.exp(-t * 18) + 42
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9)


def hat(dur=0.06):
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = np.diff(noise, prepend=0)  # basit yüksek geçiren
    return noise * np.exp(-t * 70)


def reverb(x, secs=1.6, wet=0.28):
    n = int(secs * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t * 3.2)
    ir[0] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    y = fftconvolve(x, ir)[: len(x)]
    return (1 - wet) * x + wet * y


def normalize(x, peak=0.85):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save(name, x):
    wavfile.write(os.path.join(OUT, name), SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))


# ───────────────────────── Müzik ─────────────────────────
BPM = 84
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 16
LEN = BARS * BAR
TAIL = 3.0

# Akor ilerlemesi (1 ölçü / akor): Cmaj7 - Am7 - Fmaj7 - G6
CHORDS = [
    (36, [60, 64, 67, 71]),  # C
    (33, [57, 60, 64, 67]),  # Am
    (41, [53, 57, 60, 64]),  # F
    (43, [55, 59, 62, 64]),  # G
]
PENTA = [72, 74, 76, 79, 81, 84]  # C5 D5 E5 G5 A5 C6

buf = np.zeros(int((LEN + TAIL) * SR))
for bar in range(BARS):
    root, tones = CHORDS[bar % 4]
    t0 = bar * BAR
    for m in tones:
        add(buf, t0, pad_note(m, BAR + 0.8) * 0.16)
    add(buf, t0, bass_note(root, BEAT * 2) * 0.42)
    add(buf, t0 + BEAT * 2, bass_note(root + (7 if bar % 2 else 0), BEAT * 1.8) * 0.34)
    # arpej (sekizlik)
    order = [0, 1, 2, 3, 2, 1, 2, 3] if (bar // 4) % 2 == 0 else [0, 2, 1, 3, 1, 2, 3, 2]
    for k in range(8):
        add(buf, t0 + k * BEAT / 2, pluck(tones[order[k]] + 12, 0.8) * 0.17)
    # yumuşak vuruş ve hat
    add(buf, t0, kick() * 0.30)
    add(buf, t0 + 2 * BEAT, kick() * 0.22)
    for k in range(8):
        add(buf, t0 + k * BEAT / 2 + (BEAT / 4 if k % 2 else 0) * 0, hat() * (0.035 if k % 2 else 0.02))
    # melodi (ikinci yarıda daha hareketli)
    density = 0.45 if bar < 8 else 0.7
    for k in range(4):
        if rng.random() < density:
            cand = [n for n in PENTA if (n % 12) in [m % 12 for m in tones]] or PENTA
            note = int(rng.choice(cand if k % 2 == 0 else PENTA))
            add(buf, t0 + k * BEAT + (BEAT / 2 if rng.random() < 0.3 else 0), bell(note) * 0.20)

buf = reverb(buf)
# Döngü sonu: kuyruğu başa katla (kesintisiz loop)
loop = buf[: int(LEN * SR)].copy()
tail = buf[int(LEN * SR):]
loop[: len(tail)] += tail
loop = normalize(loop, 0.8)
save("music.wav", loop)

# ───────────────────────── Ses efektleri ─────────────────────────
def sfx(notes, step, fn, gain=0.5, total=1.2):
    x = np.zeros(int(total * SR))
    for i, m in enumerate(notes):
        add(x, i * step, fn(m))
    return normalize(reverb(x, 0.6, 0.15), gain)

save("correct.wav", sfx([76, 79, 84], 0.09, lambda m: bell(m, 0.9), 0.6, 1.1))
save("over.wav", sfx([67, 64, 60, 57], 0.26, lambda m: bell(m, 1.2), 0.55, 1.8))

# yanlış: alçalan, yumuşak iki "bzzt"
def buzz(m):
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    s = np.sign(np.sin(2 * np.pi * hz(m) * t)) * 0.3 + np.sin(2 * np.pi * hz(m) * t)
    return s * env_adsr(n, 0.01, 0.05, 0.6, 0.12)

save("wrong.wav", sfx([55, 50], 0.17, buzz, 0.55, 0.7))
print("Tamam:", os.path.abspath(OUT))
