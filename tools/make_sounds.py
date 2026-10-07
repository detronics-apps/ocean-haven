"""Makes BlueHaven's placeholder sounds: short effects (audio/sfx/), nature sounds and seamless
loops (audio/ambient/) and single notes for the generated music (audio/music/), all synthesised
here (no recordings needed). Re-run it to tweak a sound: python3 tools/make_sounds.py
Then run `godot --headless --path . --import` so Godot picks up the changes.

Mono 16-bit WAV at 22050 Hz: small, and fine for soft cosy sounds. Music notes are recorded at
C4 (pads and bass lower) and pitched by the game (Sound.note).
"""
import math
import os
import random
import struct
import wave

RATE = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
TAU = math.tau
C4 = 261.63

random.seed(7)


def write(folder: str, name: str, samples: list[float], peak: float = 0.8) -> None:
    top = max(1e-6, max(abs(s) for s in samples))
    scale = peak / top
    path = os.path.join(ROOT, folder, name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))


def n(seconds: float) -> int:
    return int(seconds * RATE)


def silence(seconds: float) -> list[float]:
    return [0.0] * n(seconds)


def mix(*parts: tuple[float, list[float]]) -> list[float]:
    """Mixes (start seconds, samples) parts."""
    length = max(n(start) + len(s) for start, s in parts)
    out = [0.0] * length
    for start, s in parts:
        o = n(start)
        for i, v in enumerate(s):
            out[o + i] += v
    return out


def env(i: int, length: int, attack: float, release: float) -> float:
    """Attack / release envelope in seconds over `length` samples."""
    t = i / RATE
    rest = (length - i) / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, rest / release) if release > 0 else 1.0
    return a * r


def tone(freq: float, seconds: float, partials=((1.0, 1.0),), decay: float = 3.0, attack: float = 0.004,
         vibrato: float = 0.0, glide: float = 0.0) -> list[float]:
    """Sum of sine partials (ratio, amp) with an exponential decay (per second)."""
    length = n(seconds)
    out = []
    phases = [0.0] * len(partials)
    for i in range(length):
        t = i / RATE
        f = freq * (1.0 + glide * t / seconds) * (1.0 + vibrato * math.sin(TAU * 5.0 * t))
        v = 0.0
        for k, (ratio, amp) in enumerate(partials):
            phases[k] += TAU * f * ratio / RATE
            v += amp * math.sin(phases[k]) * math.exp(-decay * t * (1.0 + 0.6 * k))
        out.append(v * env(i, length, attack, 0.03))
    return out


def noise(seconds: float) -> list[float]:
    return [random.uniform(-1.0, 1.0) for _ in range(n(seconds))]


def lowpass(samples: list[float], cutoff) -> list[float]:
    """One-pole low-pass; `cutoff` in Hz, or a function of time (s) -> Hz."""
    out = []
    y = 0.0
    for i, x in enumerate(samples):
        c = cutoff(i / RATE) if callable(cutoff) else cutoff
        a = 1.0 - math.exp(-TAU * c / RATE)
        y += a * (x - y)
        out.append(y)
    return out


def bandpass(samples: list[float], low, high) -> list[float]:
    a = lowpass(samples, high)
    b = lowpass(samples, low)
    return [x - y for x, y in zip(a, b)]


def shape(samples: list[float], f) -> list[float]:
    """Multiplies by f(t)."""
    return [s * f(i / RATE) for i, s in enumerate(samples)]


def pluck(freq: float, seconds: float, damping: float = 0.996, bright: float = 0.5) -> list[float]:
    """Karplus-Strong plucked string."""
    period = max(2, int(RATE / freq))
    buf = lowpass(noise(period / RATE + 0.001), 2000 + bright * 6000)[:period]
    out = []
    for i in range(n(seconds)):
        v = buf[i % period]
        nxt = buf[(i + 1) % period]
        buf[i % period] = damping * 0.5 * (v + nxt)
        out.append(v)
    length = len(out)
    return [s * env(i, length, 0.002, 0.05) for i, s in enumerate(out)]


def loop(make, seconds: float, fade: float = 1.0) -> list[float]:
    """A seamless loop: makes seconds + fade, then crossfades the tail into the start."""
    raw = make(seconds + fade)
    length, x = n(seconds), n(fade)
    out = raw[:length]
    for i in range(x):
        w = i / x
        out[i] = raw[i] * w + raw[length + i] * (1.0 - w)
    return out


def semis(s: float) -> float:
    return 2.0 ** (s / 12.0)


# ---------------------------------------------------------------- music notes (at C4)

def music() -> None:
    write("music", "marimba", tone(C4, 1.6, ((1.0, 1.0), (4.0, 0.35), (10.0, 0.08)), decay=3.2, attack=0.002))
    write("music", "kalimba", mix((0, pluck(C4, 1.8, 0.997, 0.3)), (0, tone(C4 * 2, 1.8, ((1.0, 0.25),), decay=4.0))))
    write("music", "bell", tone(C4, 2.6, ((1.0, 1.0), (2.76, 0.45), (5.4, 0.2), (8.93, 0.08)), decay=1.4, attack=0.002))
    write("music", "celesta", tone(C4, 2.0, ((1.0, 1.0), (3.0, 0.2), (4.0, 0.25)), decay=2.0, attack=0.002))
    write("music", "steel", tone(C4, 1.5, ((1.0, 1.0), (2.0, 0.6), (3.01, 0.3), (4.2, 0.12)), decay=2.6, attack=0.003))
    flute = tone(C4, 1.6, ((1.0, 1.0), (2.0, 0.18), (3.0, 0.06)), decay=0.4, attack=0.09, vibrato=0.004)
    breath = shape(bandpass(noise(1.6), 600, 3000), lambda t: 0.06 * math.exp(-2.5 * t))
    write("music", "flute", [a + b for a, b in zip(flute, breath)])
    # Pad: soft detuned partials at C3, slow attack, long.
    pad_len = 4.0
    pad = [0.0] * n(pad_len)
    for detune in (-0.004, 0.0, 0.005):
        part = tone(C4 / 2 * (1.0 + detune), pad_len, ((1.0, 1.0), (2.0, 0.35), (3.0, 0.15), (4.0, 0.06)), decay=0.25, attack=0.9)
        pad = [a + b for a, b in zip(pad, part)]
    pad = [s * env(i, len(pad), 0.9, 1.4) for i, s in enumerate(pad)]
    write("music", "pad", lowpass(pad, 1800), peak=0.6)
    write("music", "bass", lowpass(tone(C4 / 4, 1.4, ((1.0, 1.0), (2.0, 0.3)), decay=2.2, attack=0.006), 900))


# ---------------------------------------------------------------- effects

def sfx() -> None:
    write("sfx", "tap", tone(1100, 0.05, ((1.0, 1.0), (2.0, 0.2)), decay=60, attack=0.001, glide=-0.25), peak=0.5)
    write("sfx", "open", tone(420, 0.14, ((1.0, 1.0), (2.0, 0.2)), decay=14, attack=0.004, glide=0.6), peak=0.5)
    write("sfx", "close", tone(700, 0.14, ((1.0, 1.0), (2.0, 0.2)), decay=14, attack=0.004, glide=-0.4), peak=0.5)
    write("sfx", "pickup", mix((0, tone(C4 * 4 * semis(4), 0.18, ((1.0, 1.0), (2.0, 0.2)), decay=16)),
                               (0.07, tone(C4 * 4 * semis(11), 0.22, ((1.0, 1.0), (2.0, 0.2)), decay=14))), peak=0.55)
    bell = ((1.0, 1.0), (2.76, 0.4), (5.4, 0.15))
    write("sfx", "coin", mix((0, tone(C4 * 4 * semis(-1), 0.5, bell, decay=6)),
                             (0.09, tone(C4 * 4 * semis(4), 0.7, bell, decay=5))), peak=0.55)
    sparkle = [(i * 0.07, tone(C4 * 4 * semis(s), 0.6, bell, decay=7)) for i, s in enumerate((0, 4, 7, 12, 16, 19))]
    shimmer = shape(bandpass(noise(1.0), 4000, 9000), lambda t: 0.05 * math.sin(math.pi * min(1.0, t)))
    write("sfx", "sparkle", mix(*sparkle, (0, shimmer)), peak=0.5)
    marimba = ((1.0, 1.0), (4.0, 0.3))
    write("sfx", "arrive", mix(*[(i * 0.14, tone(C4 * 2 * semis(s), 0.9, marimba, decay=4)) for i, s in enumerate((0, 4, 7, 12))]), peak=0.6)
    first = [(i * 0.12, tone(C4 * 2 * semis(s), 1.0, marimba, decay=3.5)) for i, s in enumerate((0, 4, 7, 9, 12))]
    write("sfx", "first_arrive", mix(*first, (0.6, tone(C4 * 4, 1.4, bell, decay=2.5)), (0.6, tone(C4 * 4 * semis(7), 1.4, bell, decay=2.5))), peak=0.6)
    write("sfx", "morning", mix(*[(i * 0.22, tone(C4 * 2 * semis(s), 1.4, bell, decay=2.2)) for i, s in enumerate((7, 4, 9, 12))]), peak=0.45)
    click = shape(bandpass(noise(0.03), 1500, 7000), lambda t: math.exp(-200 * t))
    write("sfx", "shutter", mix((0, click), (0.07, click)), peak=0.5)
    write("sfx", "free", mix(*[(i * 0.06, pluck(C4 * semis(s), 0.9, 0.995, 0.6)) for i, s in enumerate((0, 4, 7, 12, 16, 19, 24))]), peak=0.55)

    def knock() -> list[float]:
        thud = tone(190, 0.12, ((1.0, 1.0), (2.3, 0.3)), decay=35, attack=0.001)
        tick = shape(lowpass(noise(0.12), 2500), lambda t: 0.6 * math.exp(-60 * t))
        return [a + b for a, b in zip(thud, tick)]
    write("sfx", "build", mix((0, knock()), (0.16, knock()), (0.32, knock())), peak=0.6)
    chop = mix((0, tone(140, 0.25, ((1.0, 1.0),), decay=18, glide=-0.4)), (0, shape(lowpass(noise(0.25), 1800), lambda t: 0.8 * math.exp(-28 * t))))
    write("sfx", "chop", chop, peak=0.6)
    grains = shape(lowpass(noise(0.32), 1400), lambda t: (0.5 + 0.5 * math.sin(TAU * 38 * t)) * math.exp(-7 * t))
    write("sfx", "dig", grains, peak=0.55)
    write("sfx", "splash", shape(lowpass(noise(0.6), lambda t: 3500 * math.exp(-4 * t) + 300), lambda t: min(1.0, t / 0.01) * math.exp(-6 * t)), peak=0.55)
    write("sfx", "plop", mix((0, tone(380, 0.18, ((1.0, 1.0),), decay=20, glide=1.2)), (0, shape(lowpass(noise(0.18), 2000), lambda t: 0.3 * math.exp(-30 * t)))), peak=0.45)
    write("sfx", "whoosh", shape(bandpass(noise(1.3), lambda t: 200 + 500 * math.sin(math.pi * t / 1.3), lambda t: 900 + 2200 * math.sin(math.pi * t / 1.3)),
                                 lambda t: math.sin(math.pi * t / 1.3) ** 2), peak=0.5)
    write("sfx", "page", shape(bandpass(noise(0.16), 1200, 5000), lambda t: math.sin(math.pi * t / 0.16) ** 2), peak=0.35)
    write("sfx", "not_yet", mix((0, tone(C4 * 2 * semis(4), 0.2, ((1.0, 1.0),), decay=12)), (0.1, tone(C4 * 2, 0.3, ((1.0, 1.0),), decay=10))), peak=0.4)
    write("sfx", "talk", tone(C4 * 2 * semis(7), 0.06, ((1.0, 1.0), (2.0, 0.15)), decay=40, attack=0.002), peak=0.35)
    write("sfx", "hatch", mix(*[(t, tone(700 + 200 * k, 0.08, ((1.0, 1.0),), decay=50, glide=0.5)) for k, t in enumerate((0, 0.11, 0.19, 0.33))]), peak=0.45)
    thunder = shape(lowpass(noise(2.8), lambda t: 120 + 500 * math.exp(-3 * t)), lambda t: min(1.0, t / 0.05) * math.exp(-1.3 * t) * (1.0 + 0.4 * math.sin(TAU * 3 * t)))
    write("sfx", "thunder", thunder, peak=0.7)


# ---------------------------------------------------------------- nature

def ambient() -> None:
    def waves(seconds: float) -> list[float]:
        # Slow swells (periods that fit the 8 s loop) over soft surf noise.
        base = lowpass(noise(seconds), 700)
        hiss = bandpass(noise(seconds), 1500, 5000)
        swell = lambda t: 0.45 + 0.35 * math.sin(TAU * t / 8.0) ** 2 + 0.2 * math.sin(TAU * t / 4.0 + 1.0) ** 2
        return [(b * 1.0 + h * 0.18) * swell(i / RATE) for i, (b, h) in enumerate(zip(base, hiss))]
    write("ambient", "waves", loop(waves, 8.0), peak=0.5)

    def wind(seconds: float) -> list[float]:
        gust = lambda t: 0.5 + 0.3 * math.sin(TAU * t / 8.0) + 0.2 * math.sin(TAU * t / 2.0 + 0.5)
        return shape(bandpass(noise(seconds), lambda t: 250 + 150 * gust(t), lambda t: 900 + 700 * gust(t)), gust)
    write("ambient", "wind", loop(wind, 8.0), peak=0.45)

    def deep(seconds: float) -> list[float]:
        hum = [0.5 * math.sin(TAU * 55 * i / RATE) + 0.3 * math.sin(TAU * 82.5 * i / RATE + 0.3) for i in range(n(seconds))]
        drift = lowpass(noise(seconds), 160)
        breathe = lambda t: 0.7 + 0.3 * math.sin(TAU * t / 8.0)
        return [(h * 0.25 + d * 2.0) * breathe(i / RATE) for i, (h, d) in enumerate(zip(hum, drift))]
    write("ambient", "deep", loop(deep, 8.0), peak=0.45)

    def lagoon(seconds: float) -> list[float]:
        lap = lambda t: 0.5 + 0.5 * math.sin(TAU * t / 2.0) ** 4
        return shape(bandpass(noise(seconds), 300, 1600), lap)
    write("ambient", "lagoon", loop(lagoon, 8.0), peak=0.4)

    def rain(seconds: float) -> list[float]:
        return [s * (0.8 + 0.2 * math.sin(TAU * i / RATE / 4.0)) for i, s in enumerate(bandpass(noise(seconds), 800, 6000))]
    write("ambient", "rain", loop(rain, 4.0, 0.5), peak=0.4)

    # Calls (one-shots, played now and then: more of them on a healthy island).
    gull = mix(*[(k * 0.28, tone(1250 - 150 * k, 0.24, ((1.0, 1.0), (2.0, 0.5), (3.0, 0.25)), decay=4, attack=0.02, glide=-0.3)) for k in range(3)])
    write("ambient", "gull", gull, peak=0.4)
    chirp = mix(*[(k * 0.12, tone(3000 + 400 * random.random(), 0.08, ((1.0, 1.0),), decay=20, attack=0.005, glide=0.4)) for k in range(4)])
    write("ambient", "chirp", chirp, peak=0.3)
    tern = mix(*[(k * 0.15, tone(2200, 0.1, ((1.0, 1.0), (2.0, 0.4)), decay=12, attack=0.004, glide=-0.2)) for k in range(3)])
    write("ambient", "tern", tern, peak=0.3)
    whale = tone(160, 3.2, ((1.0, 1.0), (2.0, 0.3), (3.0, 0.1)), decay=0.2, attack=0.6, vibrato=0.01, glide=0.6)
    write("ambient", "whale", [s * env(i, len(whale), 0.6, 1.2) for i, s in enumerate(lowpass(whale, 800))], peak=0.4)
    creak = shape(bandpass(noise(1.2), lambda t: 120 + 200 * t, lambda t: 400 + 300 * t), lambda t: math.sin(math.pi * t / 1.2) * (0.6 + 0.4 * math.sin(TAU * 13 * t)))
    write("ambient", "creak", creak, peak=0.35)
    clicks = [s for s in silence(0.6)]
    for k in range(9):
        o = n(k * 0.05)
        for i in range(60):
            clicks[o + i] += random.uniform(-1, 1) * math.exp(-i / 8)
    whistle = tone(5000, 0.5, ((1.0, 1.0),), decay=1.0, attack=0.05, glide=0.3)
    write("ambient", "dolphin", mix((0, clicks), (0.45, whistle)), peak=0.3)
    frog = mix(*[(k * 0.22, shape(tone(420, 0.14, ((1.0, 1.0), (2.0, 0.5), (3.0, 0.4)), decay=6, attack=0.01), lambda t: 0.5 + 0.5 * math.sin(TAU * 60 * t))) for k in range(2)])
    write("ambient", "frog", frog, peak=0.3)
    write("ambient", "fish", mix((0, tone(500, 0.14, ((1.0, 1.0),), decay=25, glide=1.0)), (0.02, shape(lowpass(noise(0.3), 2500), lambda t: 0.4 * math.exp(-14 * t)))), peak=0.3)


if __name__ == "__main__":
    music()
    sfx()
    ambient()
    print("Sounds written to", os.path.normpath(ROOT))
