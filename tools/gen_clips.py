#!/usr/bin/env python3
"""Generate the toddler app's voice clips with Kokoro (Apache-2.0).

Runs on the dev Mac only. Nothing from this script or its dependencies ships
inside the iOS app -- it writes .m4a files, and that is all the app ever sees.

    python gen_clips.py            # all three voices -> out/<voice>/
    python gen_clips.py --voice af_sarah

Output filenames are exactly what RecordedSpeechService looks up:
    letter-<ID>-name.m4a / letter-<ID>-phoneme.m4a / letter-<ID>-word.m4a
    number-<ID>-name.m4a / number-<ID>-counting.m4a

HOW EACH LINE IS WRITTEN, AND WHY
---------------------------------
Three encodings are in play, each chosen because the others were tried and
failed a listening test:

1. Plain spelling ("Bee.") for the 12 letters whose names start with a
   consonant sound. The phoneme-override form made the model prepend a schwa,
   so "B" was heard as "a B". The resolved phonemes were provably clean
   ('ˈbi'), so this is an acoustic-model artifact, not a text problem -- the
   one measurable difference is that the bracket form drops its trailing full
   stop while a plain spelling keeps it.

2. Phoneme override for the other 14 letter names. "A" spelled as "Ay" was
   read as /aɪ/ ("eye"), so vowel-initial names are pinned with IPA, which
   does not suffer the schwa artifact.

3. Phoneme override for most phonics sounds, in the "released" style --
   continuants lengthened (/fː/), plosives given a following vowel (/bʌ/).
   Pure phonemes (/b/, /f/) are the textbook phonics target but were judged
   too faint, and plain spellings were mostly worse ("ff" was read "eff
   eff") -- except T, whose phonics sound is plain-spelled ("Tuh.") because
   every IPA encoding tried for it came out wrong. See LETTERS below.
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

# espeak-ng's dylib has its build machine's path baked in
# ('/Users/runner/work/espeakng-loader/...'), so without this it aborts with
# "Error processing file .../phontab: No such file or directory".
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

# id, how the NAME is spoken, phonics sound (released), picture word.
#
# Both the name and the sound are either ("spell", "Bee") -- plain text, or
# ("ipa", "ˈeɪ") -- pinned phonemes. See the header for why each letter's
# NAME uses the one it does.
#
# PHONICS SOUNDS. A bare consonant is a near-inaudible blip, so each one is
# carried by a following vowel -- the same reasoning as the app's original
# `SpeechService.ipaOverrides`, which this now matches again after a detour
# through bare lengthened consonants that sounded wrong.
#
# Which vowel (and which encoding) depends on the sound, and every
# distinction below was found by ear on af_heart, not derived from a rule:
#   sibilants (S, Z, X) take a SHORT schwa -- /sːə/ stretches the hiss into a
#     second audible "s", heard as "s suh"
#   T is plain-spelled ("Tuh.") -- the IPA form (/tə/, /tʌ/, /tˈʌ/, /tɐ/) all
#     came out wrong ("tuah"), but the plain word doesn't have that problem.
#     Found 2026-09-14, same session as the STRUT change below.
#   B, D, H, L, M, P, Q take the STRUT vowel /ʌ/ ("buh", "duh", "huh", ...)
#     pinned as IPA -- schwa /ə/ on these came out as "beh"/"deah"/"mae" etc.
#     on af_heart. Found 2026-09-14: schwa is meant for *unstressed*
#     syllables, and these are stressed one-off utterances, so /ʌ/ fits.
#     D and Q were fixed clean by this. B, H, L, M, P were NOT: they still
#     come out wrong (a front vowel, "mae"/"pae") even with /ʌ/ pinned, with
#     plain spelling ("Buh."), with /ɐ/, and with a lengthened /ʌː/ -- an
#     af_heart acoustic-model limitation on these five phonemes in isolation,
#     not a text-encoding problem. Fixed by sourcing just these five phonics
#     clips from af_bella instead, which renders /ʌ/ correctly on all five --
#     see PHONEME_VOICE_OVERRIDE below. The /ʌ/ pinning here is still what's
#     spoken; it's the synthesizing voice that differs for these five.
#   everything else takes a LONG schwa -- /fːə/ -- which gives a weak
#     consonant enough acoustic energy to register
#
LETTERS = [
    ("A", ("ipa",   "ˈeɪ"),        ("ipa",   "æː"),   "Apple"),
    ("B", ("spell", "Bee"),        ("ipa",   "bʌ"),   "Ball"),
    ("C", ("spell", "See"),        ("ipa",   "kə"),   "Cat"),
    ("D", ("spell", "Dee"),        ("ipa",   "dʌ"),   "Dog"),
    # "Eee" not "Ee": the pinned /ˈi/ came out as "Hey", and a single "Ee"
    # was no better. Judged by ear.
    ("E", ("spell", "Eee"),        ("ipa",   "ɛː"),   "Elephant"),
    ("F", ("ipa",   "ˈɛf"),        ("ipa",   "fːə"),  "Fish"),
    ("G", ("spell", "Gee"),        ("ipa",   "ɡə"),   "Goat"),
    ("H", ("ipa",   "ˈeɪtʃ"),      ("ipa",   "hʌ"),   "Hat"),
    ("I", ("ipa",   "ˈaɪ"),        ("ipa",   "ɪː"),   "Ice cream"),
    ("J", ("spell", "Jay"),        ("ipa",   "dʒə"),  "Juice"),
    ("K", ("spell", "Kay"),        ("ipa",   "kə"),   "Kite"),
    ("L", ("ipa",   "ˈɛl"),        ("ipa",   "lʌ"),   "Lion"),
    ("M", ("ipa",   "ˈɛm"),        ("ipa",   "mʌ"),   "Monkey"),
    ("N", ("ipa",   "ˈɛn"),        ("ipa",   "nːə"),  "Nest"),
    # O's sound is /ˈɒ/ -- the open back vowel. /ɑː/ and /ɔː/ both came out
    # as "eye" or "bye", and plain "ah"/"aw" spellings weren't right either.
    # Judged by ear.
    ("O", ("ipa",   "ˈoʊ"),        ("ipa",   "ˈɒ"),   "Orange"),
    ("P", ("spell", "Pee"),        ("ipa",   "pʌ"),   "Parrot"),
    ("Q", ("spell", "Cue"),        ("ipa",   "kwʌ"),  "Queen"),
    ("R", ("ipa",   "ˈɑɹ"),        ("ipa",   "ɹːə"),  "Rabbit"),
    ("S", ("ipa",   "ˈɛs"),        ("ipa",   "sə"),   "Sun"),
    # Spelled "Tee"/"Tea" both came out "See you"; the pin is the only form
    # that says T. Judged by ear.
    ("T", ("ipa",   "tˈi"),        ("spell", "Tuh"),  "Tiger"),
    # Pinned /ˈju/ came out "Ew". The plain word is what a letter U sounds like.
    ("U", ("spell", "You"),        ("ipa",   "ʌː"),   "Umbrella"),
    ("V", ("spell", "Vee"),        ("ipa",   "vːə"),  "Van"),
    ("W", ("spell", "Double you"), ("ipa",   "wə"),   "Watch"),
    ("X", ("ipa",   "ˈɛks"),       ("ipa",   "ksə"),  "X-ray"),
    # Pinned /ˈwaɪ/ prepended a stray article -- "a Y" -- the same schwa
    # artifact the header describes for phoneme-override names. The plain
    # word fixes it, same as the other consonant-initial (here: glide-
    # initial) names. Found + confirmed by ear 2026-09-14.
    ("Y", ("spell", "Why"),        ("ipa",   "jə"),   "Yo-yo"),
    # Spelled "Zee" sounded like "zei"; the pin is right.
    ("Z", ("ipa",   "zˈi"),        ("ipa",   "zə"),   "Zebra"),
]

# The number-name beat says "Number five.", not "Five."
#
# af_heart appends an /s/ to "five" when it is the whole utterance -- "Five."
# becomes "fives" -- and nothing about the spelling fixes it: punctuation,
# phoneme pins (/fˈIv/) and the spelling "Fyve" all failed. What does fix it is
# not being alone: "Five apples." and "One, two, three, four, five." are both
# clean, and in "Five. Five." only the second, isolated one is wrong. Other
# voices don't do this, and other words ending the same way ("Twelve.") are
# fine, so it is this word in this voice.
#
# The phrasing is applied to all ten so one number isn't announced differently
# from its neighbours.
NUMBER_NAME_TEMPLATE = "Number {}."

NUMBERS = ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]

VOICES = ["af_sarah", "af_heart", "af_bella"]

# af_heart cannot reliably render the phonics sound for B, H, L, M, P in
# isolation -- every encoding tried (schwa, STRUT stressed/unstressed, /ɐ/,
# long STRUT, plain spelling) came out with a substituted front vowel
# ("mae", "pae") instead. af_bella renders those five correctly with the
# same IPA pinning used in LETTERS above -- and on a side-by-side listen of
# all 26 letters, the user judged af_bella's phonics nicer across the board,
# not just on those five. So ALL of af_heart's phonics clips are sourced
# from af_bella; letter *names* and everything else stay af_heart.
# Confirmed by ear 2026-09-14.
#
# The af_heart-voiced phonics this replaces are backed up at
# VoiceClips/af_heart-phonics-backup-2026-09-14/ (not regenerated -- the
# original files -- since generation isn't deterministic) in case af_bella's
# phonics are ever rejected later; restore by copying them back over
# VoiceClips/af_heart/ and ToddlerLearningApp/Resources/Speech/, no code
# change needed. To make a partial revert (only some letters back to
# af_heart), remove those letters from the dict below and copy just their
# backed-up files back.
#
# Only applies when generating af_heart; af_bella/af_sarah runs use their
# own voice throughout, unaffected.
PHONEME_VOICE_OVERRIDE = {"af_heart": {letter_id: "af_bella" for letter_id, _, _, _ in LETTERS}}


def clip_voice(voice, stem):
    """Which voice actually synthesizes this clip -- see PHONEME_VOICE_OVERRIDE."""
    if stem.startswith("letter-") and stem.endswith("-phoneme"):
        letter_id = stem.split("-")[1]
        override = PHONEME_VOICE_OVERRIDE.get(voice, {}).get(letter_id)
        if override:
            return override
    return voice

# Generate at Kokoro's natural pace and slow it down at playback instead
# (RecordedClipPlayer.playbackRate).
#
# Generating slow corrupts the audio: at speed 0.8 the model prepends a schwa,
# so "Trace B" came out as "a-Trace B" and a lone "Bee" as "a B". Confirmed by
# transcribing the same lines generated at 1.0 / 0.9 / 0.8 -- clean at 1.0,
# broken at 0.8. Short clips and lines beginning with a stressed consonant were
# worst hit. Do not lower this to slow the voice down.
SPEED = 1.0


def spoken_form(letter_id, form):
    """A letter's name or phonics sound as text for Kokoro -- see the header."""
    kind, value = form
    return value if kind == "spell" else f"[{letter_id}](/{value}/)"


def clips():
    """[(filename_stem, text)] -- names match RecordedSpeechService's lookup."""
    items = []
    for letter_id, name, sound, word in LETTERS:
        spoken = spoken_form(letter_id, name)
        items.append((f"letter-{letter_id}-name", f"{spoken}."))
        items.append((f"letter-{letter_id}-phoneme", f"{spoken_form(letter_id, sound)}."))
        items.append((f"letter-{letter_id}-word", f"{spoken} is for {word}."))
    for index, number in enumerate(NUMBERS, start=1):
        items.append((f"number-{index}-name", NUMBER_NAME_TEMPLATE.format(number)))
        # The counting run stays plain text: the template exists to fix how a
        # number sounds alone, and pinning one word inside a list of ten
        # changes the rhythm of the whole line.
        #
        # Re-rolling one of these makes its timing file stale -- re-run
        # gen_count_timings.py afterwards (check_keys.py fails until you do).
        # It regenerates this exact text, so keep the two in step.
        items.append((f"number-{index}-counting", ", ".join(NUMBERS[:index]) + "."))
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


def to_m4a(wav_path: Path, m4a_path: Path):
    """Mono 48 kbps AAC, silence trimmed off both ends.

    Trimming is part of generating, not a later clean-up step: Kokoro pads
    roughly 0.45s of silence onto the front of a clip and 0.55s onto the end,
    which stacks with the gap between beats into seconds of dead air. Doing it
    here means a regenerated set can never quietly lose the fix.
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--voice", action="append", dest="voices")
    parser.add_argument("--out", default="out")
    parser.add_argument(
        "--only", action="append", default=[], metavar="SUBSTRING",
        help="only clips whose key contains this (repeatable), e.g. --only letter-E- "
             "--only number-5-. Leaves every other clip in the output directory "
             "untouched, so a single bad clip can be re-rolled without redoing the set.",
    )
    parser.add_argument(
        "--force", action="store_true",
        help="regenerate even if the .m4a already exists. Generation is not "
             "deterministic, so this is how a clip that came out wrong is re-rolled.",
    )
    args = parser.parse_args()

    if shutil.which("ffmpeg") is None:
        sys.exit("ffmpeg not found -- needed to encode .m4a")

    from kokoro import KPipeline

    pipeline = KPipeline(lang_code="a")  # American English
    items = clips()
    if args.only:
        items = [(stem, text) for stem, text in items
                 if any(fragment in stem for fragment in args.only)]
        if not items:
            sys.exit(f"--only {args.only} matched no clips")
    problems = []

    for voice in args.voices or VOICES:
        out_dir = Path(args.out) / voice
        # A full run starts from an empty directory: a stale clip from an
        # earlier encoding silently shipping would be worse than a missing one,
        # which just falls back. A targeted run must not wipe the other clips.
        if not args.only and out_dir.exists():
            shutil.rmtree(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)

        print(f"=== {voice}: {len(items)} clips ===", flush=True)
        for stem, text in items:
            if not args.force and (out_dir / f"{stem}.m4a").exists():
                continue
            wav_path = out_dir / f"{stem}.wav"
            m4a_path = out_dir / f"{stem}.m4a"
            try:
                seconds = synthesise(pipeline, text, wav_path, clip_voice(voice, stem))
                to_m4a(wav_path, m4a_path)
                wav_path.unlink()
                if seconds < 0.15:
                    problems.append((voice, stem, f"suspiciously short ({seconds:.2f}s)"))
            except Exception as error:
                problems.append((voice, stem, f"{type(error).__name__}: {error}"))

    print()
    if problems:
        print(f"{len(problems)} PROBLEM(S):")
        for voice, stem, why in problems:
            print(f"  {voice:10s} {stem:26s} {why}")
    else:
        print(f"All clips generated for {len(args.voices or VOICES)} voice(s).")


if __name__ == "__main__":
    main()
