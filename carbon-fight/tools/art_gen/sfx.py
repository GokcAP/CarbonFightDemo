"""8-bit ses efektleri ve kısa chiptune döngüsü (22050 Hz, 16-bit mono WAV)."""
import os, sys, wave
import numpy as np

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else "out/sfx"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(3)


def t_(d):
    return np.arange(int(SR * d)) / SR


def sweep(f0, f1, d):
    f = np.linspace(f0, f1, int(SR * d))
    return np.cumsum(f) / SR


def square(phase, duty=0.5):
    return np.where((phase % 1.0) < duty, 1.0, -1.0)


def tri(phase):
    return 2 * np.abs(2 * (phase % 1.0) - 1) - 1


def noise(d, hold=1):
    n = rng.uniform(-1, 1, int(SR * d) // hold + 1)
    return np.repeat(n, hold)[: int(SR * d)]


def env(n, a=0.005, r=None, d=None):
    total = n / SR
    e = np.ones(n)
    ai = max(1, int(a * SR))
    e[:ai] = np.linspace(0, 1, ai)
    if r is None:
        e *= np.linspace(1, 0, n) ** 1.5
    else:
        ri = int(r * SR)
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def note(freq, d, wave_fn=square, duty=0.5, vol=1.0):
    ph = t_(d) * freq
    s = square(ph, duty) if wave_fn is square else wave_fn(ph)
    return s * env(len(s), r=min(0.03, d / 3)) * vol


def save(name, x, vol=0.5):
    x = np.clip(x * vol, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())


def cat(*xs):
    return np.concatenate(xs)


save("click", square(sweep(900, 1200, 0.035), 0.25) * env(int(SR * 0.035)), 0.25)
save("place", cat(note(523, 0.05, duty=0.25), note(784, 0.07, duty=0.25)), 0.35)
save("merge", cat(*[note(f, 0.06, duty=0.25) for f in (523, 659, 784, 1047)], note(1319, 0.15, duty=0.125)), 0.32)
x = square(sweep(220, 90, 0.1), 0.5) * 0.6 + noise(0.1, 2) * 0.5
save("hit", x * env(len(x)), 0.4)
x = square(sweep(140, 50, 0.18)) * 0.7 + noise(0.18, 6) * 0.6
save("boss_hit", x * env(len(x)), 0.5)
x = square(sweep(420, 110, 0.16), 0.5)
save("hurt", x * env(len(x)), 0.35)
x = noise(0.35, 4) * 0.8 + square(sweep(160, 40, 0.35)) * 0.3
save("break", x * env(len(x)), 0.45)
x = tri(sweep(400, 1000, 0.3)) * (0.6 + 0.4 * square(t_(0.3) * 24))
save("heal", x * env(len(x), r=0.1), 0.35)
d = 0.6
ph = sweep(110, 60, d) + 0.02 * np.sin(t_(d) * 2 * np.pi * 9)
x = (2 * (ph % 1) - 1) * 0.7 + noise(d, 8) * 0.4
save("roar", x * env(len(x), a=0.05, r=0.25), 0.45)
x = square(sweep(200, 900, 0.5), 0.25) * square(t_(0.5) * 30) * 0.5 + tri(sweep(100, 450, 0.5)) * 0.5
save("spawn", x * env(len(x), a=0.02, r=0.15), 0.35)
save("sacrifice", cat(square(sweep(300, 900, 0.12), 0.25) * 0.6, (noise(0.4, 3) * 0.8 + square(sweep(120, 40, 0.4)) * 0.4) * env(int(SR * 0.4))), 0.45)
save("win", cat(*[note(f, 0.12) for f in (523, 659, 784)], note(1047, 0.45, duty=0.25)), 0.3)
save("lose", cat(*[note(f, 0.18, duty=0.25) for f in (392, 330, 262)], note(196, 0.6, wave_fn=tri)), 0.35)

# ---- Müzik: 8 ölçü, 120 BPM, Am - F - C - G
bpm = 120; beat = 60 / bpm; step = beat / 2
chords = [(220.0, [440, 523, 659]), (174.6, [349, 440, 523]), (130.8, [523, 659, 784]), (196.0, [392, 494, 587])]
bars = []
for rep in range(2):
    for root, arp in chords:
        bar = []
        for i in range(8):
            f = arp[i % 3] * (2 if (rep and i in (3, 7)) else 1)
            lead = note(f, step, duty=0.125, vol=0.25)
            bass = note(root / 2 if i % 2 == 0 else root, step, wave_fn=tri, vol=0.55)
            hat = noise(step, 1) * env(int(SR * step)) ** 6 * (0.15 if i % 2 else 0.08)
            kick = (tri(sweep(150, 40, step)) * env(int(SR * step)) ** 2 * 0.5) if i % 4 == 0 else 0
            bar.append(lead + bass + hat + kick)
        bars.append(cat(*bar))
save("music", cat(*bars), 0.45)
print("ok")
