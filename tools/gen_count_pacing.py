#!/usr/bin/env python3
"""Re-pace a counting clip so every number is separated by the same silence.

    python3 tools/gen_count_pacing.py VoiceClips/af_heart --numbers 5,10 --gap 0.45 --out /tmp/pacing_samples
    python3 tools/gen_count_pacing.py VoiceClips/af_heart --gap 0.45 --apply   # the real run, one voice
    tools/use_voice.sh af_heart                                                # resync Resources/Speech after --apply

WHY THIS EXISTS
---------------
`number-<N>-counting.m4a` is Kokoro's natural reading of "One, two, three...":
the model was never asked for a pause, and it doesn't give one -- measuring the
gap between consecutive onsets in the shipped timing file shows next to no
silence at all (0-35ms in the ten-count) and the *spacing itself* is uneven
(226-400ms between onsets, before the 0.8x playback slowdown even applies).
Both are why a child following the highlight finds it rushed and irregular.

HOW
---
No new synthesis. The words are already correct -- only their spacing is
wrong -- so this cuts the existing clip at its own onsets (the same instants
`RecordedSpeechService` already trusts to fire the highlight) and re-stitches
the pieces with one fixed silence in between. A few milliseconds are faded at
each cut to avoid an audible click; nothing about the voice or the words
changes, so this needs no re-verification by `verify_clips.py` and no
listening pass on the words themselves -- only on the new rhythm.

The output gets its own onsets, recomputed from the new fixed spacing, and its
own `audio_sha1` -- both written into a fresh sidecar `.json`, in the same
shape `countingOnsets(for:in:)` and `check_keys.py` already expect.
"""

import argparse
import hashlib
import json
import struct
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SAMPLE_RATE = 24000

# Trailing pad after the last number -- same convention as gen_clips.to_m4a's
# apad, so the clip doesn't end on a hard cut.
END_PAD = 0.08

# Length of the linear fade applied at each cut, in samples -- long enough to
# silence a click, short enough not to eat into the word.
FADE_SAMPLES = 80  # ~3.3ms at 24kHz


def decode(path: Path) -> list:
    raw = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", str(path),
         "-f", "f32le", "-ac", "1", "-ar", str(SAMPLE_RATE), "-"],
        capture_output=True, check=True,
    ).stdout
    n = len(raw) // 4
    return list(struct.unpack(f"<{n}f", raw))


def encode(samples: list, out_path: Path):
    raw = struct.pack(f"<{len(samples)}f", *samples)
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error",
         "-f", "f32le", "-ac", "1", "-ar", str(SAMPLE_RATE), "-i", "-",
         "-ac", "1", "-c:a", "aac", "-b:a", "48k", str(out_path)],
        input=raw, check=True,
    )


def fade(segment: list) -> list:
    """In-place-equivalent linear fade in/out, so a hard cut doesn't click."""
    n = len(segment)
    edge = min(FADE_SAMPLES, n // 2)
    out = list(segment)
    for i in range(edge):
        gain_in = i / edge
        out[i] *= gain_in
        j = n - 1 - i
        gain_out = i / edge
        out[j] *= gain_out
    return out


def repace(clip: Path, timing: Path, gap: float):
    """(new_samples, new_onsets) for `clip`, evenly spaced by `gap` seconds."""
    data = json.loads(timing.read_text())
    onsets = data["onsets"]
    words = data["words"]

    audio = decode(clip)
    bounds = [int(round(t * SAMPLE_RATE)) for t in onsets] + [len(audio)]

    silence = [0.0] * int(round(gap * SAMPLE_RATE))
    pad = [0.0] * int(round(END_PAD * SAMPLE_RATE))

    new_samples: list = []
    new_onsets: list = []
    for i in range(len(words)):
        segment = fade(audio[bounds[i]:bounds[i + 1]])
        new_onsets.append(round(len(new_samples) / SAMPLE_RATE, 3))
        new_samples.extend(segment)
        if i < len(words) - 1:
            new_samples.extend(silence)
    new_samples.extend(pad)

    return new_samples, words, new_onsets


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("voice_dir", type=Path, help="e.g. VoiceClips/af_heart")
    parser.add_argument("--gap", type=float, required=True,
                         help="silence between numbers, in seconds, measured in the "
                              "clip as generated -- playback then stretches it "
                              "another 1.25x (RecordedClipPlayer.playbackRate=0.8)")
    parser.add_argument("--numbers", default=",".join(str(n) for n in range(1, 11)),
                         help="comma-separated counts to re-pace, default all of 1-10")
    parser.add_argument("--out", type=Path, default=None,
                         help="write here instead of the voice dir -- for samples")
    parser.add_argument("--apply", action="store_true",
                         help="write into voice_dir itself, replacing the shipped clips. "
                              "Without this, --out is required.")
    args = parser.parse_args()

    if not args.apply and args.out is None:
        sys.exit("pass --out DIR for a sample run, or --apply to replace the shipped clips")

    out_dir = args.voice_dir if args.apply else args.out
    out_dir.mkdir(parents=True, exist_ok=True)

    numbers = [int(n) for n in args.numbers.split(",")]
    for number in numbers:
        clip = args.voice_dir / f"number-{number}-counting.m4a"
        timing = clip.with_suffix(".json")
        if not clip.exists() or not timing.exists():
            print(f"  skip {clip.name}: missing clip or timing file")
            continue

        samples, words, onsets = repace(clip, timing, args.gap)
        out_clip = out_dir / clip.name
        encode(samples, out_clip)

        out_timing = out_clip.with_suffix(".json")
        out_timing.write_text(json.dumps({
            "words": words,
            "onsets": onsets,
            "audio_sha1": hashlib.sha1(out_clip.read_bytes()).hexdigest(),
        }) + "\n")

        print(f"  {out_clip}  gap={args.gap}s  onsets={onsets}")

    print(f"\n{len(numbers)} clip(s) written to {out_dir}")
    if not args.apply:
        print("Sample run -- listen before using --apply, then tools/use_voice.sh <voice> to resync the bundle.")


if __name__ == "__main__":
    main()
