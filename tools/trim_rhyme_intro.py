#!/usr/bin/env python3
"""Trim the non-vocal intro/outro music off each rhyme recording.

    ./venv/bin/python tools/trim_rhyme_intro.py ToddlerLearningApp/Resources/RhymeAudio --out /tmp/trimmed
    ./venv/bin/python tools/trim_rhyme_intro.py ToddlerLearningApp/Resources/RhymeAudio --apply

WHY THIS EXISTS
---------------
The licensed song pack's tracks are sing-along recordings: most open and close
with several seconds of instrumental music before and after the actual
singing. `RhymeAudioService` plays the whole file, so a child waits through
that padding before any words arrive.

HOW
---
The cut points come from where the *singing* starts and stops, measured on a
vocals-only stem:

1. Demucs separates each track into vocals / everything-else. During an
   instrumental intro the vocals stem is near-silent, which is exactly the
   boundary we need and which no amount of silence detection on the full mix
   can find -- the mix isn't silent there, it's music.
2. The stem's RMS envelope (20ms frames) is thresholded at -40dB relative to
   its own 99th-percentile level. The first and last sustained run above that
   line are the vocal onset and offset.
3. The *original* mp3 is cut at those points, padded slightly so no sung word
   is clipped.

Whisper was tried first and is not used: its segment timestamps anchor the
first segment at 0.00 almost every time, so the intro was never cut. Its
word-level timestamps (`word_timestamps=True`) do fix that and agreed with
this method to within ~40ms on a spot check, but they still hallucinate on
tracks with long non-vocal stretches -- one 173s track had Whisper reporting
nothing at all for the first 60 seconds.

Everything between onset and offset is left alone: an instrumental bridge
*inside* a song survives, only the ends are cut.

`--out DIR` writes trimmed copies there for a listen before touching the
bundle; `--apply` overwrites in place. Cuts use `-c copy`, so kept audio is
bit-identical to the source -- only mp3 frame granularity (~26ms) limits cut
precision, which is inaudible at a start/end trim.
"""

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf

# Padding around the detected vocal span, so singing doesn't start or end
# abruptly mid-breath.
PRE_PAD = 0.2
POST_PAD = 0.5

# RMS frame size for the envelope, and how far below the stem's own loud level
# still counts as "singing here". -40dB is deliberately generous: erring early
# keeps the attack of the first word, where erring late would clip it.
FRAME = 0.02
THRESHOLD_DB = -40.0

# A run this long must clear the threshold before it counts, so a single
# frame of instrument bleed in the vocals stem can't be mistaken for singing.
MIN_RUN_FRAMES = 5

# Demucs doesn't separate perfectly: a whistle or a lead synth over an
# instrumental intro can leave enough in the vocals stem to read as singing,
# which left seven seconds of music on the front of some tracks. So the energy
# bounds are checked against the first and last word Whisper actually hears,
# and a disagreement bigger than this hands the decision to the words -- the
# stem has energy there, but nobody is singing yet.
WORD_DISAGREEMENT = 1.2


def duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
        capture_output=True, check=True, text=True,
    ).stdout
    return float(out.strip())


def separate(files: list[Path], work_dir: Path) -> Path:
    """Run demucs once over every file — the model loads once, not per track."""
    subprocess.run(
        [sys.executable, "-m", "demucs", "--two-stems=vocals",
         "-o", str(work_dir), *[str(f) for f in files]],
        check=True,
    )
    return work_dir / "htdemucs"


def vocal_bounds(stem: Path) -> tuple[float, float]:
    """(start, end) in seconds of the sung portion of a vocals stem."""
    audio, sr = sf.read(stem)
    mono = audio.mean(axis=1) if audio.ndim > 1 else audio

    hop = int(FRAME * sr)
    usable = len(mono) - (len(mono) % hop)
    frames = mono[:usable].reshape(-1, hop)
    rms = np.sqrt(np.mean(frames ** 2, axis=1))

    reference = np.percentile(rms, 99)
    if reference <= 0:
        raise ValueError("vocals stem is silent")
    level = 20 * np.log10(np.maximum(rms, 1e-10) / reference)

    loud = level > THRESHOLD_DB
    # Keep only frames inside a run of at least MIN_RUN_FRAMES — see above.
    runs = np.convolve(loud.astype(int), np.ones(MIN_RUN_FRAMES, dtype=int), mode="same")
    sustained = np.flatnonzero(runs >= MIN_RUN_FRAMES)
    if len(sustained) == 0:
        raise ValueError("no sustained vocals found")

    return sustained[0] * hop / sr, (sustained[-1] + 1) * hop / sr


def sung_words(model, stem: Path) -> tuple[float, float] | None:
    """(first word start, last word end) heard in the stem, or None if silent."""
    result = model.transcribe(str(stem), word_timestamps=True, fp16=False)
    words = [word for segment in result["segments"] for word in segment.get("words", [])]
    if not words:
        return None
    return words[0]["start"], words[-1]["end"]


def agreed_bounds(energy: tuple[float, float],
                   words: tuple[float, float] | None) -> tuple[float, float]:
    """Energy bounds, overruled by the words where the two disagree badly.

    Only ever tightens: the words can move the start later or the end earlier,
    never the reverse, so a word Whisper places late can't eat into singing the
    envelope already found. See WORD_DISAGREEMENT.
    """
    start, end = energy
    if words is None:
        return start, end
    first, last = words
    if first - start > WORD_DISAGREEMENT:
        start = first
    if end - last > WORD_DISAGREEMENT:
        end = last
    return start, end


def trim(path: Path, start: float, end: float, total: float, out_path: Path):
    begin = max(0.0, start - PRE_PAD)
    finish = min(total, end + POST_PAD)
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error",
         "-ss", f"{begin:.3f}", "-to", f"{finish:.3f}",
         "-i", str(path), "-c", "copy", str(out_path)],
        check=True,
    )
    return begin, finish


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("--out", type=Path, default=None,
                         help="write trimmed copies here instead of the source dir")
    parser.add_argument("--apply", action="store_true",
                         help="overwrite files in source_dir in place")
    parser.add_argument("--only", action="append", default=[],
                         help="only files whose name contains this substring (repeatable)")
    args = parser.parse_args()

    if not args.apply and args.out is None:
        sys.exit("pass --out DIR for a sample run, or --apply to trim in place")

    out_dir = args.source_dir if args.apply else args.out
    out_dir.mkdir(parents=True, exist_ok=True)

    files = sorted(path for path in args.source_dir.iterdir()
                    if path.suffix in {".mp3", ".m4a"})
    if args.only:
        files = [f for f in files if any(fragment in f.name for fragment in args.only)]
    if not files:
        sys.exit("no files matched")

    import whisper
    model = whisper.load_model("small")

    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        stems_root = separate(files, work)

        print(f"\n{len(files)} file(s)\n")
        problems = []
        for path in files:
            total = duration(path)
            stem = stems_root / path.stem / "vocals.wav"
            try:
                start, end = agreed_bounds(vocal_bounds(stem), sung_words(model, stem))
            except (ValueError, RuntimeError) as error:
                problems.append((path.name, str(error)))
                print(f"  {path.name:38s} SKIPPED: {error}")
                continue

            destination = out_dir / path.name
            scratch = work / f"trimmed-{path.name}"
            begin, finish = trim(path, start, end, total, scratch)
            shutil.move(str(scratch), destination)

            print(f"  {path.name:38s} {total:6.1f}s -> {finish - begin:6.1f}s  "
                  f"(cut {begin:4.1f}s front, {total - finish:4.1f}s back)")

    print()
    if problems:
        print(f"{len(problems)} problem(s) — left untrimmed:")
        for name, why in problems:
            print(f"  {name}: {why}")
        return 1
    print(f"Done. Output in {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
