#!/usr/bin/env python3
"""Generates the bundled sound effects (PLAN.md §18).

The app ships no third-party audio: every cue is a short synthesised tone
written straight to `assets/audio/` as 16-bit mono PCM WAV. Re-run this script
after changing a cue:

    python3 up_sudoku/tool/generate_sounds.py

`audioplayers` plays the files with `AssetSource`, so nothing is ever
downloaded at runtime.
"""

import math
import os
import struct
import wave

RATE = 44100
ATTACK = 0.005  # seconds, avoids the click of an abrupt start


def _note(freq, seconds, peak):
    """One enveloped note: sine plus a quiet second harmonic."""
    total = int(RATE * seconds)
    samples = []
    for n in range(total):
        t = n / RATE
        envelope = min(1.0, t / ATTACK) * math.exp(-3.2 * t / seconds)
        value = math.sin(2 * math.pi * freq * t)
        value += 0.28 * math.sin(4 * math.pi * freq * t)
        samples.append(peak * envelope * value / 1.28)
    return samples


def _buzz(freq, seconds, peak):
    """A harsher, square-ish tone for the wrong-digit cue."""
    total = int(RATE * seconds)
    samples = []
    for n in range(total):
        t = n / RATE
        envelope = min(1.0, t / ATTACK) * math.exp(-2.4 * t / seconds)
        value = math.sin(2 * math.pi * freq * t)
        value += 0.5 * math.sin(2 * math.pi * freq * 3 * t)
        samples.append(peak * envelope * value / 1.5)
    return samples


def _silence(seconds):
    return [0.0] * int(RATE * seconds)


def _join(*parts):
    out = []
    for part in parts:
        out.extend(part)
    return out


# Each cue is a list of notes; the names match `assets/audio/*.wav`.
CUES = {
    "tap": _join(_note(880, 0.045, 0.16)),
    "place": _join(_note(660, 0.055, 0.22), _note(990, 0.075, 0.20)),
    "error": _join(_buzz(196, 0.10, 0.22), _silence(0.02), _buzz(147, 0.12, 0.20)),
    "unit_complete": _join(
        _note(784, 0.065, 0.18),
        _note(988, 0.065, 0.18),
        _note(1319, 0.10, 0.18),
    ),
    "win": _join(
        _note(523, 0.09, 0.20),
        _note(659, 0.09, 0.20),
        _note(784, 0.09, 0.20),
        _note(1047, 0.20, 0.20),
    ),
    "lose": _join(
        _note(440, 0.12, 0.18),
        _note(349, 0.12, 0.18),
        _note(262, 0.24, 0.16),
    ),
}


def write_wav(path, samples):
    frames = bytearray()
    for sample in samples:
        value = max(-1.0, min(1.0, sample))
        frames.extend(struct.pack("<h", int(value * 32767)))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(bytes(frames))


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)
    for name, samples in CUES.items():
        path = os.path.join(out_dir, name + ".wav")
        write_wav(path, samples)
        print("wrote %s (%d bytes)" % (path, os.path.getsize(path)))


if __name__ == "__main__":
    main()
