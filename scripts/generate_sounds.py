#!/usr/bin/env python3
"""Generate the five Politiface UI sound effects.

These are original synthesized works, created by this script and licensed
under MIT like the rest of the repository. No third-party samples, no
downloaded assets: everything is computed from the recipes below, so the
committed WAVs are fully auditable and bit-for-bit regenerable.

Palette: woody / paper. A marimba-like strike ("tone") is the shared
building block; every pitch sits in A major (A, C#, E) so any accidental
sequence of sounds is musical. All output is 16-bit PCM mono WAV at
44.1 kHz, quiet by design (sounds sit under haptics, not over them).

Usage:
    python3 scripts/generate_sounds.py            # write app/assets/audio/
    python3 scripts/generate_sounds.py --check    # regenerate to a temp dir
                                                  # and diff against committed

Deterministic: all noise comes from random.Random(20260712), so output is
bit-for-bit identical across runs and machines.
"""

import argparse
import hashlib
import math
import os
import random
import struct
import sys
import tempfile
import wave

SR = 44100
SEED = 20260712
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "app", "assets", "audio")

# Hard cap from the design budget: the whole directory stays under 350 KB.
BUDGET_BYTES = 350 * 1024


# ── DSP helpers ──────────────────────────────────────────────────────────────

def lowpass(x, fc):
    """One-pole lowpass at cutoff fc."""
    a = 1.0 - math.exp(-2.0 * math.pi * fc / SR)
    y = []
    prev = 0.0
    for v in x:
        prev += a * (v - prev)
        y.append(prev)
    return y


def highpass(x, fc):
    """One-pole highpass at cutoff fc (input minus its lowpassed self)."""
    lp = lowpass(x, fc)
    return [v - l for v, l in zip(x, lp)]


def tone(f, dur, tau, rng):
    """Marimba-like woody strike at fundamental f.

    Inharmonic partials (1.0f, 3.9f, 9.2f) with per-partial exponential
    decays (tau, tau/2.5, tau/5), a 3 ms attack ramp, plus an 8 ms
    lowpassed-noise mallet contact at onset.
    """
    n = int(SR * dur)
    out = [0.0] * n
    partials = [
        (1.0, 1.00, tau),
        (3.9, 0.25, tau / 2.5),
        (9.2, 0.08, tau / 5.0),
    ]
    for mult, gain, tau_p in partials:
        w = 2.0 * math.pi * f * mult
        for i in range(n):
            t = i / SR
            env = math.exp(-t / tau_p) * min(1.0, t / 0.003)
            out[i] += gain * env * math.sin(w * t)
    # Mallet contact: 8 ms of lowpassed (2500 Hz) white noise at onset.
    contact_n = int(SR * 0.008)
    noise = lowpass([rng.uniform(-1.0, 1.0) for _ in range(contact_n)], 2500)
    for i in range(min(contact_n, n)):
        t = i / SR
        out[i] += 0.12 * noise[i] * math.exp(-t / 0.004)
    return out


def mix_at(dest, src, offset_s, gain):
    """Add src into dest starting at offset_s seconds."""
    start = int(SR * offset_s)
    for i, v in enumerate(src):
        j = start + i
        if j >= len(dest):
            break
        dest[j] += gain * v


def hump(t, start, peak, end):
    """Raised-cosine amplitude hump: 0 at start, 1 at peak, 0 at end."""
    if t < start or t > end:
        return 0.0
    if t <= peak:
        return 0.5 * (1.0 - math.cos(math.pi * (t - start) / (peak - start)))
    return 0.5 * (1.0 + math.cos(math.pi * (t - peak) / (end - peak)))


def finish(samples, target_dbfs):
    """Declick fades, then peak-normalize to target_dbfs."""
    n = len(samples)
    fade_in = int(SR * 0.002)   # 2 ms linear fade-in
    fade_out = int(SR * 0.008)  # fade to zero at the end
    for i in range(min(fade_in, n)):
        samples[i] *= i / fade_in
    for i in range(min(fade_out, n)):
        samples[n - 1 - i] *= i / fade_out
    peak = max(abs(v) for v in samples)
    if peak > 0.0:
        scale = (10.0 ** (target_dbfs / 20.0)) / peak
        samples = [v * scale for v in samples]
    return samples


# ── Recipes ──────────────────────────────────────────────────────────────────

def make_flip(rng):
    """Card flip: 100 ms of bandpassed paper noise, double turning-page hump.

    Normalized to -14 dBFS.
    """
    dur = 0.100
    n = int(SR * dur)
    x = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    # Bandpass: one-pole HP at 1000 Hz then one-pole LP at 3500 Hz, each
    # applied twice for steeper skirts.
    x = highpass(x, 1000)
    x = highpass(x, 1000)
    x = lowpass(x, 3500)
    x = lowpass(x, 3500)
    out = []
    for i, v in enumerate(x):
        t = i / SR
        amp = hump(t, 0.000, 0.030, 0.090) + 0.5 * hump(t, 0.030, 0.055, 0.090)
        out.append(v * amp)
    return finish(out, -14.0)


def make_correct(rng):
    """Correct: 250 ms single woodblock tick, E5. Normalized to -12 dBFS."""
    out = tone(659.25, 0.250, 0.090, rng)
    return finish(out, -12.0)


def make_incorrect(rng):
    """Incorrect: 220 ms muted felt thud, neutral not punitive.

    Sine gliding G3 (196 Hz) down to E3 (165 Hz) over the first 120 ms then
    holding, amplitude exp(-t/0.070), plus a lowpassed (1200 Hz) noise tap
    at onset. No upper partials, no buzzer character. Normalized to -12 dBFS.
    """
    dur = 0.220
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = 196.0 + (165.0 - 196.0) * min(t, 0.120) / 0.120
        phase += 2.0 * math.pi * f / SR
        out.append(math.sin(phase) * math.exp(-t / 0.070))
    tap_n = int(SR * 0.010)
    noise = lowpass([rng.uniform(-1.0, 1.0) for _ in range(tap_n)], 1200)
    for i in range(min(tap_n, n)):
        t = i / SR
        out[i] += 0.08 * noise[i] * math.exp(-t / 0.005)
    return finish(out, -12.0)


def make_complete(rng):
    """Complete: 650 ms two-note woody resolve, A4 then E5 at 140 ms.

    Normalized to -12 dBFS.
    """
    dur = 0.650
    out = [0.0] * int(SR * dur)
    mix_at(out, tone(440.00, dur, 0.160, rng), 0.000, 0.85)
    mix_at(out, tone(659.25, dur - 0.140, 0.160, rng), 0.140, 1.00)
    return finish(out, -12.0)


def make_milestone(rng):
    """Milestone: 900 ms ascending A-major arpeggio (A4, C#5, E5).

    The last note rings (tau 0.260). Normalized to -11 dBFS.
    """
    dur = 0.900
    out = [0.0] * int(SR * dur)
    mix_at(out, tone(440.00, dur, 0.140, rng), 0.000, 0.80)
    mix_at(out, tone(554.37, dur - 0.130, 0.140, rng), 0.130, 0.85)
    mix_at(out, tone(659.25, dur - 0.260, 0.260, rng), 0.260, 1.00)
    return finish(out, -11.0)


RECIPES = [
    ("flip.wav", make_flip),
    ("correct.wav", make_correct),
    ("incorrect.wav", make_incorrect),
    ("complete.wav", make_complete),
    ("milestone.wav", make_milestone),
]


# ── Output ───────────────────────────────────────────────────────────────────

def write_wav(path, samples):
    frames = b"".join(
        struct.pack("<h", max(-32768, min(32767, int(round(v * 32767.0)))))
        for v in samples
    )
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def generate(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    rows = []
    total = 0
    for name, recipe in RECIPES:
        # Fresh seeded RNG per file: each file is independently reproducible.
        samples = recipe(random.Random(SEED))
        path = os.path.join(out_dir, name)
        write_wav(path, samples)
        size = os.path.getsize(path)
        total += size
        peak = max(abs(v) for v in samples)
        peak_db = 20.0 * math.log10(peak) if peak > 0 else float("-inf")
        rows.append((name, size, len(samples) / SR, peak_db, sha256(path)))
    return rows, total


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="regenerate to a temp dir and diff against the committed files",
    )
    args = parser.parse_args()

    if args.check:
        with tempfile.TemporaryDirectory() as tmp:
            rows, _ = generate(tmp)
            ok = True
            for name, _, _, _, digest in rows:
                committed = os.path.join(OUT_DIR, name)
                if not os.path.exists(committed):
                    print(f"MISSING  {name}")
                    ok = False
                elif sha256(committed) != digest:
                    print(f"DIFFERS  {name}")
                    ok = False
                else:
                    print(f"OK       {name}")
            sys.exit(0 if ok else 1)

    rows, total = generate(OUT_DIR)
    print(f"{'file':<16}{'bytes':>8}{'dur (s)':>10}{'peak dBFS':>12}  sha256")
    for name, size, dur, peak_db, digest in rows:
        print(f"{name:<16}{size:>8}{dur:>10.3f}{peak_db:>12.1f}  {digest}")
    print(f"{'total':<16}{total:>8}  (budget {BUDGET_BYTES})")
    if total > BUDGET_BYTES:
        print("ERROR: over the 350 KB budget", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
