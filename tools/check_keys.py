#!/usr/bin/env python3
"""Cross-check the clip keys the app can ask for against the files that exist.

    python check_keys.py ../../../ToddlerLearningApp/Resources/Speech

Why this exists: a missing or misspelled clip key fails *silently*. There is no
crash and no build warning — `RecordedSpeechService` simply falls back to the
synthesizer for that line, so the only symptom is one robotic sentence in the
middle of an otherwise recorded app. With ~2,000 keys that is not something a
person can eyeball.

Two directions, both of which matter:

  MISSING  — a key the app can emit with no file behind it. The bug above.
  ORPHAN   — a file no key can ever reach. Harmless at runtime but it means
             either the app stopped using a line, or a key was renamed on one
             side only. Dead weight in the bundle, and usually a sign the two
             sides have drifted apart.

It also checks the Learn Numbers counting timings (gen_count_timings.py), which
fail just as quietly: without them the count plays but nothing lights up, and
with a stale one things light up at the wrong moments.

The expected key set is derived from the same tables the generators use, so
this checks the *app's* view against the *bundle's* view rather than checking
a generator against itself.
"""

import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from gen_phase_b import (  # noqa: E402
    LETTERS, PICTURE_WORDS, NUMBER_NAMES, TRACE_DIGITS, COUNTING_OBJECTS, WORDS,
    PRAISE, RETRY_PRAISE, GREETINGS, slug,
)


def expected_keys():
    """Every clip key reachable from the app, mirroring Content/SpokenClips.swift."""
    keys = set()

    # Phase A — teaching sequences (SpeechService.teachLetter / teachNumber).
    for letter in LETTERS:
        keys.update({
            f"letter-{letter}-name",
            f"letter-{letter}-phoneme",
            f"letter-{letter}-word",
        })
    for number in NUMBER_NAMES:
        keys.update({f"number-{number}-name", f"number-{number}-counting"})

    # Phase B — Find the Letter, Trace, Build the Word shared letter lines.
    for letter in LETTERS:
        for variant in range(5):
            keys.add(f"quiz-prompt-{variant}-{letter}")
        for variant in range(4):
            keys.add(f"quiz-tapped-{variant}-{letter}")
            keys.add(f"quiz-retry-{variant}-{letter}")
        keys.update({
            f"letter-thats-{letter}",
            f"letter-weneed-{letter}",
            f"letter-heres-{letter}",
            f"trace-prompt-{letter}",
        })
        for word in PICTURE_WORDS[letter]:
            keys.update({
                f"quiz-isfor-{letter}-{slug(word)}",
                f"quiz-isforx-{letter}-{slug(word)}",
                f"quiz-hereitis-{letter}-{slug(word)}",
            })

    # Trace Numbers.
    for digit in TRACE_DIGITS:
        keys.update({f"trace-prompt-number-{digit}", f"number-thats-{digit}"})

    # Count & Find.
    for singular, plural in COUNTING_OBJECTS:
        keys.add(f"count-prompt-{slug(plural)}")
    for count in NUMBER_NAMES:
        for singular, plural in COUNTING_OBJECTS:
            things = singular if count == 1 else plural
            keys.add(f"count-answer-{count}-{slug(things)}")
            keys.add(f"count-retry-{count}-{slug(things)}")

    # Build the Word.
    for word in WORDS:
        keys.update({
            f"word-spell-{slug(word)}",
            f"word-alone-{slug(word)}",
            f"word-starts-{slug(word)}",
        })
    keys.update({"word-last-letter", "word-next", "word-you-did-it"})

    # Praise — name-free only. A named opener is deliberately never recorded.
    for index in range(len(PRAISE)):
        keys.add(f"praise-{index}")
    for index in range(len(RETRY_PRAISE)):
        keys.add(f"praise-retry-{index}")
    for index in range(len(GREETINGS)):
        keys.add(f"greeting-{index}")

    return keys


def timing_problems(clips_dir):
    """Counting clips whose timing file is missing, stale, or the wrong length."""
    problems = []
    for number in NUMBER_NAMES:
        clip = clips_dir / f"number-{number}-counting.m4a"
        if not clip.exists():
            continue  # already reported as MISSING
        timing_path = clip.with_suffix(".json")
        if not timing_path.exists():
            problems.append(f"NO TIMING {timing_path.name}")
            continue
        timing = json.loads(timing_path.read_text())
        if timing.get("audio_sha1") != hashlib.sha1(clip.read_bytes()).hexdigest():
            problems.append(f"STALE     {timing_path.name} (measured from a different clip)")
        elif len(timing.get("onsets", [])) != number:
            problems.append(f"BAD       {timing_path.name} (needs {number} onsets)")
    return problems


def main():
    if len(sys.argv) < 2:
        sys.exit(f"usage: {Path(__file__).name} <clips-dir>")

    clips_dir = Path(sys.argv[1])
    if not clips_dir.is_dir():
        sys.exit(f"not a directory: {clips_dir}")

    expected = expected_keys()
    present = {path.stem for path in clips_dir.glob("*.m4a")}

    # The rhyme clip lives in the same flat bundle and is not a speech key.
    present.discard("twinkle-twinkle")

    missing = sorted(expected - present)
    orphans = sorted(present - expected)

    print(f"expected {len(expected)} keys, found {len(present)} files in {clips_dir}")
    print(f"  missing: {len(missing)}")
    print(f"  orphans: {len(orphans)}")

    for key in missing[:25]:
        print(f"  MISSING  {key}")
    if len(missing) > 25:
        print(f"  ... and {len(missing) - 25} more")

    for key in orphans[:15]:
        print(f"  ORPHAN   {key}")
    if len(orphans) > 15:
        print(f"  ... and {len(orphans) - 15} more")

    timings = timing_problems(clips_dir)
    print(f"  counting timings: {len(timings)} problem(s)")
    for problem in timings:
        print(f"  {problem}")
    if timings:
        print("  fix: ./venv/bin/python tools/gen_count_timings.py, then tools/use_voice.sh")

    return 1 if missing or timings else 0


if __name__ == "__main__":
    sys.exit(main())
