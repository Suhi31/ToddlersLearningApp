#!/usr/bin/env python3
"""Generate the Phase B voice clips — the games, tracing and praise.

Runs on the dev Mac only; the app ships nothing but the resulting .m4a files.

    python gen_phase_b.py --voice af_sarah
    python gen_phase_b.py --voice af_sarah --dry-run   # list keys, generate nothing

EVERY KEY HERE MUST MATCH Content/SpokenClips.swift EXACTLY.
A key that doesn't match is invisible at runtime: no crash, no warning, just a
line that quietly falls back to the synthesizer. `--dry-run` prints the full key
list so it can be diffed against what the app actually asks for.

Encoding rules are inherited from gen_clips.py (see docs/VOICE_CLIPS.md):
plain spelling for consonant-initial letter names, pinned phonemes for the rest.
Here that matters wherever a line *contains* a letter name — "That's the letter
B" has to say "Bee", not "a B".
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def _configure_espeak():
    if os.environ.get("ESPEAK_DATA_PATH"):
        return
    brew_data = "/opt/homebrew/share/espeak-ng-data"
    brew_lib = "/opt/homebrew/lib/libespeak-ng.dylib"
    if os.path.isfile(os.path.join(brew_data, "phontab")):
        os.environ["ESPEAK_DATA_PATH"] = brew_data
        if os.path.isfile(brew_lib):
            os.environ.setdefault("PHONEMIZER_ESPEAK_LIBRARY", brew_lib)
        return
    try:
        import espeakng_loader
        os.environ["ESPEAK_DATA_PATH"] = espeakng_loader.get_data_path()
        os.environ.setdefault("PHONEMIZER_ESPEAK_LIBRARY", espeakng_loader.get_library_path())
    except Exception:
        pass


_configure_espeak()

# --- Letter names: how each one must be SPOKEN inside a sentence -------------
# Sourced from gen_clips.py's LETTERS -- NOT duplicated here. This used to be
# its own hardcoded dict, and it silently drifted out of sync with
# gen_clips.py's tuning: E, T, U, Y and Z all still carried an OLD, already-
# rejected encoding (e.g. U's pinned /ˈju/, which gen_clips.py replaced with
# plain "You" because it came out "Ew" -- exactly the bug reported here,
# still live in this file even though gen_clips.py had the fix). Found
# 2026-09-14 while chasing the Y "a Y" bug, which turned out to be the same
# class of staleness. A single source of truth removes the sync burden
# instead of relying on someone remembering to update both.
import gen_clips  # noqa: E402  (after _configure_espeak, matching gen_clips.py's own ordering)

LETTER_SPOKEN = {letter_id: name for letter_id, name, sound, word in gen_clips.LETTERS}

LETTERS = list(LETTER_SPOKEN)

# Letter -> picture words. Mirrors AlphabetContent.letters + secondPictureWords.
PICTURE_WORDS = {
    "A": ["Apple", "Ant"], "B": ["Ball", "Balloon"], "C": ["Cat", "Car"],
    "D": ["Dog", "Donut"], "E": ["Elephant", "Egg"], "F": ["Fish", "Flower"],
    "G": ["Goat", "Gift"], "H": ["Hat", "House"], "I": ["Ice cream", "Ice"],
    "J": ["Juice"], "K": ["Kite", "Key"], "L": ["Lion", "Lemon"],
    "M": ["Monkey", "Moon"], "N": ["Nest", "Nose"], "O": ["Orange", "Octopus"],
    "P": ["Parrot", "Pizza"], "Q": ["Queen"], "R": ["Rabbit", "Rainbow"],
    "S": ["Sun", "Snake"], "T": ["Tiger", "Train"], "U": ["Umbrella", "Unicorn"],
    "V": ["Van", "Violin"], "W": ["Watch", "Whale"], "X": ["X-ray"],
    "Y": ["Yo-yo", "Yellow"], "Z": ["Zebra"],
}

NUMBER_NAMES = {1: "One", 2: "Two", 3: "Three", 4: "Four", 5: "Five",
                6: "Six", 7: "Seven", 8: "Eight", 9: "Nine", 10: "Ten"}

# Trace Numbers: the digits 0-9, not the counting numbers 1-10 above. Mirrors
# the keys of NumberTracePathContent.paths (check_content_sync.py compares them).
TRACE_DIGITS = {0: "zero", 1: "one", 2: "two", 3: "three", 4: "four",
                5: "five", 6: "six", 7: "seven", 8: "eight", 9: "nine"}

# Mirrors NumberContent.countingObjects — (singular, plural).
COUNTING_OBJECTS = [
    ("apple", "apples"), ("banana", "bananas"), ("strawberry", "strawberries"),
    ("orange", "oranges"), ("carrot", "carrots"), ("cookie", "cookies"),
    ("cupcake", "cupcakes"), ("donut", "donuts"), ("dog", "dogs"),
    ("cat", "cats"), ("fish", "fish"), ("butterfly", "butterflies"),
    ("frog", "frogs"), ("chick", "chicks"), ("ladybug", "ladybugs"),
    ("turtle", "turtles"), ("duck", "ducks"), ("bee", "bees"),
    ("bunny", "bunnies"), ("elephant", "elephants"), ("balloon", "balloons"),
    ("star", "stars"), ("car", "cars"), ("bus", "buses"), ("boat", "boats"),
    ("rocket", "rockets"), ("ball", "balls"), ("present", "presents"),
    ("teddy bear", "teddy bears"), ("flower", "flowers"), ("tree", "trees"),
]

# Mirrors WordBuildContent.words — id only; the spoken form is capitalised.
# This list was once written from memory and 19 of the 50 were wrong, so more
# than a third of Build the Word fell back to the synthesiser -- and nothing
# caught it, because check_keys.py derives its expectations from this same
# list and so reported "0 missing" against a set of clips the app never asks
# for. Verify against the Swift file, never against recollection:
#
#   grep -oE 'WordItem\(id: "[A-Z]+"' ToddlerLearningApp/Content/WordBuildContent.swift \
#     | sed 's/.*id: "//;s/"//' | tr 'A-Z' 'a-z' | sort
#
WORDS = [
    "ant", "bat", "bear", "bed", "bird", "boat", "box", "bug", "bus", "cake",
    "car", "cat", "corn", "cow", "crab", "cup", "dog", "drum", "duck", "ear",
    "fan", "fish", "fox", "frog", "gift", "hat", "hen", "ice", "jar", "key",
    "kite", "leg", "lion", "log", "map", "milk", "net", "nut", "owl", "pen",
    # "saw" is deliberately absent -- af_heart says it with a leading vowel
    # ("isa"). Removed from WordBuildContent.swift too; keep the two in step.
    "pie", "pig", "ram", "sock", "star", "sun", "tie", "van", "web",
]

# Must match Praise.exclamations in Content/SpokenPhrases.swift exactly --
# the app indexes clips by position, so removing one shifts every clip after
# it and they all have to be regenerated. Two are absent: "High five" (the
# voice says it as "high fives", the same trouble it has with the number) and
# "Woohoo" (didn't sound natural). Both judged by ear.
PRAISE = ["Yes", "Great job", "Well done", "You got it", "Brilliant",
          "Fantastic", "Amazing", "Super job", "Way to go", "You nailed it"]

RETRY_PRAISE = ["That's it!", "There it is!", "You found it!"]

# Must match Greeting.lines in Content/SpokenPhrases.swift. Name-free, so the
# mascot's greeting can be a recording like everything else.
GREETINGS = [
    "Hi! Ready to play?",
    "Hello! Let's have some fun!",
    "Hey! Ready for an adventure?",
    "Hiya! What should we learn today?",
    "Boo! Just kidding — let's play!",
]

# Generate at Kokoro's natural pace and slow it down at playback instead
# (RecordedClipPlayer.playbackRate). See the note in gen_clips.py: generating
# at 0.8 makes the model prepend a schwa ("a-Trace B"), confirmed by
# transcribing the same line at 1.0 / 0.9 / 0.8. Do not lower this.
SPEED = 1.0

# See the comment at letter-weneed- in clips() below.
WENEED_PERIOD_LETTERS = {"B", "C", "D", "E", "G", "P", "T", "V", "Z"}

# Per-clip-key voice override -- mirrors gen_clips.py's PHONEME_VOICE_OVERRIDE.
# Only af_heart needs entries; a run for another --voice is unaffected.
CLIP_VOICE_OVERRIDE = {
    "af_heart": {
        # Period alone wasn't enough for B specifically -- af_bella fixed
        # it, matching the phonics-sound fix (af_heart already struggles to
        # render B cleanly; see PHONEME_VOICE_OVERRIDE in gen_clips.py).
        "letter-weneed-B": "af_bella",
    },
}

# Per-clip-key pause-length override for shrink_pauses() -- overrides
# PAUSE_TARGET_SECONDS for specific keys. (Empty for now: letter-weneed-U
# used to need this at up to 250ms, but SPLIT_SYNTHESIS below fixed it a
# different way, at the standard 120ms. Kept as a mechanism in case another
# clip needs a longer/shorter target than the default.)
PAUSE_TARGET_OVERRIDE = {}

# Clips where even a 250ms shrink_pauses() gap didn't reliably read as a
# pause (see letter-weneed-U below) -- Kokoro's own "..." silence for these
# apparently isn't genuinely silent (likely a very quiet, breathy word
# onset bleeding into it just under the -30dB detection threshold, so what
# measures as "pause" isn't perceived as one). Fixed by synthesizing the
# two halves as separate utterances and joining them with TRUE digital
# silence -- not Kokoro's rendered gap at all. {key: (part1_text,
# part2_text)}; gap length is pause_target(key), same as shrink_pauses().
SPLIT_SYNTHESIS = {
    # Confirmed by ear 2026-09-15: even a true, unambiguous silence only
    # needed the standard 120ms here once it was real silence -- the
    # earlier "needs more time" reading was wrong; the gap just wasn't
    # actually silent.
    "letter-weneed-U": ("We need.", "You!"),
}


def clip_voice(voice, key):
    """Which voice actually synthesizes this clip -- see CLIP_VOICE_OVERRIDE."""
    return CLIP_VOICE_OVERRIDE.get(voice, {}).get(key, voice)


def pause_target(key):
    """The shrink_pauses()/SPLIT_SYNTHESIS gap for this clip -- see
    PAUSE_TARGET_OVERRIDE."""
    return PAUSE_TARGET_OVERRIDE.get(key, PAUSE_TARGET_SECONDS)


def slug(text):
    """Mirrors Clip.slug in SpokenClips.swift."""
    return text.lower().replace("'", "").replace(" ", "-")


def spoken_letter(letter_id):
    """A letter named inside a sentence — just "Bee", matching Spoken.letter.

    Deliberately not "the letter Bee": that scaffolding existed to stop the
    synthesizer reading a bare "A" as the word "a", but a recording has no such
    problem, and "the letter Bee" hears as the insect.
    """
    kind, value = LETTER_SPOKEN[letter_id]
    return value if kind == "spell" else f"[{letter_id}](/{value}/)"


def letter_alone(letter_id):
    kind, value = LETTER_SPOKEN[letter_id]
    return value if kind == "spell" else f"[{letter_id}](/{value}/)"


def clips():
    """[(key, text)] — every recordable line in Phase B."""
    items = []

    # --- Find the Letter ---
    for L in LETTERS:
        letter = spoken_letter(L)
        # A "..." right before the target letter is a deliberate pause+
        # emphasis cue (see PAUSE_TARGET_SECONDS): without it the letter at
        # the end of a prompt sentence blurs in and isn't always clearly
        # heard. Confirmed by ear 2026-09-14; shrink_pauses() then trims the
        # pause Kokoro renders for "..." down to a short, consistent length.
        for i, text in enumerate([
            f"Can you find... {letter}?", f"Where's... {letter}?", f"Find... {letter}!",
            f"Can you tap... {letter}?", f"Can you spot... {letter}?",
        ]):
            items.append((f"quiz-prompt-{i}-{L}", text))

        for i, text in enumerate([
            # Unchanged: "That's X!" alone was already judged clear.
            f"That's {letter}!",
            # Restructured, not just paused: a pause after "Good try" (so it
            # doesn't run into "That's") plus one before the letter. Judged
            # by ear 2026-09-14.
            f"Good try... That's... {letter}.",
            # Single pause before the letter -- one clause, same shape as
            # the quiz-prompt lines above. Judged by ear 2026-09-14.
            f"That one is... {letter}.",
            # Same "interjection! That's X." shape as index 1, so it gets
            # the same two-pause treatment. Judged by ear 2026-09-14.
            f"Almost... That's... {letter}.",
        ]):
            items.append((f"quiz-tapped-{i}-{L}", text))

        for i, text in enumerate([
            f"Can you find... {letter}?", f"Where's... {letter}?",
            f"Let's look for... {letter}.", f"Find... {letter}!",
        ]):
            items.append((f"quiz-retry-{i}-{L}", text))

        items.append((f"letter-thats-{L}", f"That's... {letter}."))
        # "We need... X!" mispronounced "need" as "nead" for 9 of the 26
        # letters -- an af_heart artifact tied to which letter follows, not
        # a text problem with "need" itself (found 2026-09-15). A period
        # instead of "..." fixed 8 of the 9; B needed af_heart replaced with
        # af_bella too (CLIP_VOICE_OVERRIDE below), same as its phonics
        # sound needed earlier. The other 17 letters were already correct
        # with "..." and were left alone rather than risk swapping in an
        # untested period version.
        weneed_text = (f"We need. {letter}!" if L in WENEED_PERIOD_LETTERS
                        else f"We need... {letter}!")
        items.append((f"letter-weneed-{L}", weneed_text))
        items.append((f"letter-heres-{L}", f"Here's... {letter}!"))

        for word in PICTURE_WORDS[L]:
            spoken = f"{letter_alone(L)} is for {word}"
            items.append((f"quiz-isfor-{L}-{slug(word)}", f"{spoken}."))
            items.append((f"quiz-isforx-{L}-{slug(word)}", f"{spoken}!"))
            items.append((f"quiz-hereitis-{L}-{slug(word)}", f"{spoken}. Here it is!"))

        # No trace-done clip: finishing a letter plays a praise opener followed
        # by `letter-thats-<L>`, so a dedicated recording would be the same
        # words twice under two names.
        items.append((f"trace-prompt-{L}", f"Trace {letter}."))

    # --- Trace Numbers ---
    # Written as words: the model reads digits too, but a word is what the
    # recording must say, so spell it out rather than trust the normaliser.
    # "five" is never alone here -- af_heart says a lone "Five." as "fives".
    for digit, name in TRACE_DIGITS.items():
        items.append((f"trace-prompt-number-{digit}", f"Trace {name}."))
        items.append((f"number-thats-{digit}", f"That's {name}."))

    # --- Count & Find ---
    for singular, plural in COUNTING_OBJECTS:
        items.append((f"count-prompt-{slug(plural)}", f"How many {plural} do you see?"))
    for count, name in NUMBER_NAMES.items():
        for singular, plural in COUNTING_OBJECTS:
            things = singular if count == 1 else plural
            verb = "is" if count == 1 else "are"
            items.append((f"count-answer-{count}-{slug(things)}", f"{name} {things}!"))
            items.append((f"count-retry-{count}-{slug(things)}",
                          f"There {verb} {name.lower()} {things}. Let's try again."))

    # --- Build the Word ---
    for word in WORDS:
        spoken = word.capitalize()
        items.append((f"word-spell-{slug(word)}", f"Let's spell {spoken}!"))
        items.append((f"word-alone-{slug(word)}", f"{spoken}!"))
        # Not "What does X start with?" -- the voice swallows "does" into
        # something that hears as "is". Must match slotQuestion in
        # ViewModels/WordBuildViewModel.swift.
        items.append((f"word-starts-{slug(word)}", f"What's the first letter in {spoken}?"))
    items.append(("word-last-letter", "What's the last letter?"))
    items.append(("word-next", "What comes next?"))
    items.append(("word-you-did-it", "You did it!"))

    # --- Praise (name-free only; a named opener is never recorded) ---
    for i, text in enumerate(PRAISE):
        items.append((f"praise-{i}", f"{text}!"))
    for i, text in enumerate(RETRY_PRAISE):
        items.append((f"praise-retry-{i}", text))

    for i, text in enumerate(GREETINGS):
        items.append((f"greeting-{i}", text))

    return items


def synthesise(pipeline, text, wav_path, voice):
    import numpy as np
    import soundfile as sf

    chunks = [audio for _, _, audio in pipeline(text, voice=voice, speed=SPEED)]
    if not chunks:
        raise RuntimeError(f"no audio for {text!r}")
    audio = chunks[0] if len(chunks) == 1 else np.concatenate(chunks)
    sf.write(wav_path, audio, 24000)
    return len(audio) / 24000


def to_m4a_trimmed(wav_path: Path, m4a_path: Path):
    """Mono 48 kbps AAC, silence trimmed off both ends.

    Trimming is not cosmetic: untrimmed clips carried ~0.45s of leading and
    ~0.55s of trailing silence, which stacked with the gap between lines into
    seconds of dead air.
    """
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
         "-af", ("silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.05:detection=peak,"
                 "areverse,"
                 "silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.05:detection=peak,"
                 "areverse,apad=pad_dur=0.08"),
         "-ac", "1", "-c:a", "aac", "-b:a", "48k", str(m4a_path)],
        check=True,
    )


# A "..." in the text is Kokoro's cue for a deliberate mid-sentence pause
# (used to set off the target letter -- see clips() above), but the pause it
# renders is ~230-365ms, which measured too long by ear. Shrunk to this after
# generating. Found + confirmed by ear 2026-09-14.
PAUSE_TARGET_SECONDS = 0.12
_PAUSE_EDGE_GUARD_SECONDS = 0.12  # ignore silence this close to the trimmed clip's own edges -- that's leading/trailing padding, not a "..." pause


def _probe_duration(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
        capture_output=True, text=True, check=True,
    )
    return float(out.stdout.strip())


def _find_silences(path, noise_db=-30, min_dur=0.05):
    out = subprocess.run(
        ["ffmpeg", "-i", str(path), "-af", f"silencedetect=noise={noise_db}dB:d={min_dur}", "-f", "null", "-"],
        capture_output=True, text=True,
    ).stderr
    starts = [float(m) for m in re.findall(r"silence_start:\s*([\d.]+)", out)]
    ends = [float(m) for m in re.findall(r"silence_end:\s*([\d.]+)", out)]
    return list(zip(starts, ends))


def shrink_pauses(m4a_path: Path, target=PAUSE_TARGET_SECONDS):
    """Cut the middle out of every internal silence gap longer than `target`,
    in place. Keeps the edges of each gap (so the preceding word still
    trails off and the following word still leads in naturally) rather than
    hard-cutting at a single point.
    """
    duration = _probe_duration(m4a_path)
    silences = _find_silences(m4a_path)
    internal = sorted(
        (s, e) for s, e in silences
        if s > _PAUSE_EDGE_GUARD_SECONDS and e < duration - _PAUSE_EDGE_GUARD_SECONDS
        and (e - s) > target
    )
    if not internal:
        return

    keep = target / 2
    segments = []
    cursor = 0.0
    for s, e in internal:
        segments.append((cursor, s + keep))
        cursor = e - keep
    segments.append((cursor, duration))

    filt_parts = []
    labels = []
    for i, (a, b) in enumerate(segments):
        filt_parts.append(f"[0:a]atrim=start={a}:end={b},asetpts=PTS-STARTPTS[a{i}]")
        labels.append(f"[a{i}]")
    filt = ";".join(filt_parts) + ";" + "".join(labels) + f"concat=n={len(segments)}:v=0:a=1[out]"

    tmp_path = m4a_path.with_suffix(".shrunk.m4a")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(m4a_path),
         "-filter_complex", filt, "-map", "[out]",
         "-c:a", "aac", "-b:a", "48k", str(tmp_path)],
        check=True,
    )
    tmp_path.replace(m4a_path)


def synthesise_split(pipeline, part1, part2, m4a_path: Path, voice, gap_seconds=PAUSE_TARGET_SECONDS):
    """Two independently-synthesized utterances joined by TRUE digital
    silence -- see SPLIT_SYNTHESIS for why this exists instead of just
    shrink_pauses().
    """
    stem = m4a_path.stem
    wav1, wav2 = m4a_path.with_name(f"{stem}.part1.wav"), m4a_path.with_name(f"{stem}.part2.wav")
    m4a1, m4a2 = m4a_path.with_name(f"{stem}.part1.m4a"), m4a_path.with_name(f"{stem}.part2.m4a")
    synthesise(pipeline, part1, wav1, voice)
    synthesise(pipeline, part2, wav2, voice)
    to_m4a_trimmed(wav1, m4a1)
    to_m4a_trimmed(wav2, m4a2)
    wav1.unlink()
    wav2.unlink()
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error",
         "-i", str(m4a1), "-i", str(m4a2),
         "-f", "lavfi", "-t", str(gap_seconds), "-i", "anullsrc=r=24000:cl=mono",
         "-filter_complex", "[0:a][2:a][1:a]concat=n=3:v=0:a=1[out]",
         "-map", "[out]", "-c:a", "aac", "-b:a", "48k", str(m4a_path)],
        check=True,
    )
    m4a1.unlink()
    m4a2.unlink()
    return _probe_duration(m4a_path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--voice", default="af_sarah")
    parser.add_argument("--out", default="phase_b")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--only", action="append", default=[], metavar="SUBSTRING",
        help="only clips whose key contains this (repeatable), e.g. "
             "--only word-spell-bug --only praise-. Every other clip is left alone.",
    )
    parser.add_argument(
        "--force", action="store_true",
        help="regenerate even if the .m4a already exists. Without this an "
             "existing clip is skipped, which is what makes a long run resumable; "
             "with it, a clip that came out wrong can be re-rolled.",
    )
    args = parser.parse_args()

    items = clips()
    if args.only:
        items = [(key, text) for key, text in items
                 if any(fragment in key for fragment in args.only)]
        if not items:
            sys.exit(f"--only {args.only} matched no clips")
    keys = [key for key, _ in items]
    duplicates = {k for k in keys if keys.count(k) > 1}

    if duplicates:
        print(f"WARNING: {len(duplicates)} duplicate key(s): {sorted(duplicates)[:5]}")

    if args.dry_run:
        for key, text in items:
            print(f"{key}\t{text}")
        print(f"\n{len(items)} clips, {len(set(keys))} unique keys", file=sys.stderr)
        return

    if shutil.which("ffmpeg") is None:
        sys.exit("ffmpeg not found")

    from kokoro import KPipeline

    pipeline = KPipeline(lang_code="a")
    out_dir = Path(args.out) / args.voice
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"{len(items)} clips -> {out_dir}", flush=True)
    problems = []
    done = 0

    for key, text in items:
        m4a_path = out_dir / f"{key}.m4a"
        # Resumable: a long run can be interrupted and picked up. --force
        # overrides it, which is how a clip that came out wrong is re-rolled
        # (generation is not deterministic).
        if m4a_path.exists() and not args.force:
            done += 1
            continue
        wav_path = out_dir / f"{key}.wav"
        try:
            if key in SPLIT_SYNTHESIS:
                part1, part2 = SPLIT_SYNTHESIS[key]
                seconds = synthesise_split(pipeline, part1, part2, m4a_path,
                                            clip_voice(args.voice, key), pause_target(key))
            else:
                seconds = synthesise(pipeline, text, wav_path, clip_voice(args.voice, key))
                to_m4a_trimmed(wav_path, m4a_path)
                wav_path.unlink()
                if "..." in text:
                    shrink_pauses(m4a_path, target=pause_target(key))
            if seconds < 0.15:
                problems.append((key, f"suspiciously short ({seconds:.2f}s)"))
        except Exception as error:
            problems.append((key, f"{type(error).__name__}: {error}"))
        done += 1
        if done % 100 == 0:
            print(f"  {done}/{len(items)}", flush=True)

    print()
    if problems:
        print(f"{len(problems)} PROBLEM(S):")
        for key, why in problems[:20]:
            print(f"  {key:40s} {why}")
    else:
        print(f"All {len(items)} clips generated.")


if __name__ == "__main__":
    main()
