#!/usr/bin/env python3
"""Measure when each number is said in the Learn Numbers counting clips.

    ./venv/bin/python tools/gen_count_timings.py                   # every voice in VoiceClips/
    ./venv/bin/python tools/gen_count_timings.py VoiceClips/af_heart

Writes `number-<N>-counting.json` beside each `number-<N>-counting.m4a`:

    {"words": ["one", "two", "three"], "onsets": [0.0, 0.302, 0.54], "audio_sha1": "..."}

WHY THIS EXISTS
---------------
Learn Numbers lights up each object as its number is said. The synthesizer can
do that by itself -- it speaks every number as a separate utterance -- but a
recording of "One, two, three." is one file with no timing inside it. These
onsets are that timing: `RecordedSpeechService` fires the highlight as playback
reaches each one.

HOW
---
The line is generated again with the same voice, and Kokoro's own word
timestamps are taken from that copy. The copy is thrown away; the shipped clip
is never touched, so nothing here needs a new listen.

That works because Kokoro's *timing* is deterministic even though its audio is
not: the duration model gives identical word timestamps run after run, and a
fresh copy's speech is the same length as the bundled clip's to within a few
milliseconds. Only the waveform varies, which is where a re-rolled clip's
artifacts come from. Each clip is still checked -- see `MAX_SPAN_DIFFERENCE`.

Whisper's word timestamps were tried first and are not good enough: the
English model put "three" 130ms late in the seven-count, and squeezed two
words under 120ms apart in ten of the thirty clips.

Onsets are seconds into the *recording*. The app plays clips slowed down
(`RecordedClipPlayer.playbackRate`) and compares them against the player's own
position in the clip, so nothing here needs to know the playback speed.

`audio_sha1` ties a timing file to the exact clip it was measured from.
`check_keys.py` fails on a mismatch, because a re-rolled counting clip with the
old timings would light objects up at the wrong moments -- silently.
"""

import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))

# Importing gen_clips also points espeak-ng at its data -- see _configure_espeak.
from gen_clips import NUMBERS, SPEED  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
SAMPLE_RATE = 24000

# Where speech starts and stops: the same -40dB peak threshold `gen_clips.to_m4a`
# trims silence at, so both measurements find the same edges.
SILENCE = 10 ** (-40 / 20)

# How far the fresh copy's speech may differ in length from the bundled clip's
# before the timings are refused. A match proves the clip is this text in this
# voice at this speed, and so that its words fall where the copy's do. Real
# matches are within ~10ms; this allows for AAC blurring the edges.
MAX_SPAN_DIFFERENCE = 0.03

# No number is said faster than this, so two onsets closer together mean the
# timings are wrong, not that the voice was quick.
MIN_WORD_SECONDS = 0.12


def sha1(path: Path) -> str:
    return hashlib.sha1(path.read_bytes()).hexdigest()


def decode(path: Path):
    raw = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", str(path),
         "-f", "f32le", "-ac", "1", "-ar", str(SAMPLE_RATE), "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.float32)


def speech_edges(audio):
    """(start, end) in seconds of the first and last sample above SILENCE."""
    loud = np.flatnonzero(np.abs(audio) > SILENCE)
    if len(loud) == 0:
        raise ValueError("clip is silent")
    return loud[0] / SAMPLE_RATE, (loud[-1] + 1) / SAMPLE_RATE


def measure(pipeline, voice: str, clip: Path, count: int):
    """([(word, onset)], length difference in seconds) for one counting clip,
    or raise with the reason."""
    expected = [n.lower() for n in NUMBERS[:count]]
    # Must match gen_clips.clips() exactly, or the copy is a different line.
    text = ", ".join(NUMBERS[:count]) + "."

    results = list(pipeline(text, voice=voice, speed=SPEED))
    if len(results) != 1:
        raise ValueError(f"Kokoro split the line into {len(results)} chunks")
    copy = results[0]

    words = [(token.text.lower(), token.start_ts) for token in copy.tokens
             if token.text.strip(",.")]
    if [word for word, _ in words] != expected:
        raise ValueError(f"copy says {[word for word, _ in words]}, expected {expected}")

    copy_start, copy_end = speech_edges(copy.audio.numpy())
    clip_start, clip_end = speech_edges(decode(clip))
    difference = (clip_end - clip_start) - (copy_end - copy_start)
    if abs(difference) > MAX_SPAN_DIFFERENCE:
        raise ValueError(
            f"speech is {difference * 1000:+.0f}ms longer than a fresh copy -- this clip was "
            f"not generated from {text!r} at speed {SPEED}, so its words won't be where the copy's are")

    # The copy has Kokoro's padding in front; the clip has been trimmed.
    shift = clip_start - copy_start
    # The highlight for "one" starts with playback, not a few ms into it.
    onsets = [0.0] + [round(float(start + shift), 3) for _, start in words[1:]]
    for previous, current in zip(onsets, onsets[1:]):
        if current - previous < MIN_WORD_SECONDS:
            raise ValueError(f"onsets {onsets} put two words under {MIN_WORD_SECONDS}s apart")

    return list(zip(expected, onsets)), difference


def main():
    dirs = [Path(arg) for arg in sys.argv[1:]] or sorted(
        path for path in (REPO / "VoiceClips").iterdir() if path.is_dir())

    from kokoro import KPipeline

    pipeline = KPipeline(lang_code="a")  # American English, as gen_clips
    problems = []

    for clips_dir in dirs:
        # VoiceClips/<voice>/ is named after the voice that generated it. The
        # bundled copy is not timed directly: use_voice.sh carries these files
        # across with the clips.
        voice = clips_dir.name
        print(f"=== {voice} ===", flush=True)
        for count in range(1, len(NUMBERS) + 1):
            clip = clips_dir / f"number-{count}-counting.m4a"
            if not clip.exists():
                problems.append((clip, "no clip"))
                continue
            try:
                measured, difference = measure(pipeline, voice, clip, count)
            except (ValueError, subprocess.CalledProcessError) as error:
                problems.append((clip, str(error)))
                continue

            timing = {
                "words": [word for word, _ in measured],
                "onsets": [onset for _, onset in measured],
                "audio_sha1": sha1(clip),
            }
            clip.with_suffix(".json").write_text(json.dumps(timing) + "\n")
            print(f"  {clip.stem:20s} length {difference * 1000:+3.0f}ms  {timing['onsets']}")

    print()
    if problems:
        print(f"{len(problems)} PROBLEM(S) -- no timing file written for these:")
        for clip, why in problems:
            print(f"  {clip.parent.name}/{clip.name}: {why}")
        return 1
    print("All counting clips timed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
