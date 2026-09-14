#!/usr/bin/env python3
"""Transcribe every generated clip and compare it against what it should say.

    python verify_clips.py <clips-dir> [--limit N]

This exists because nothing else catches the failure that actually happened.
The key cross-check proves a file exists for every key; the simulator probe
proves the app plays clips instead of synthesizing. Neither can hear that a
clip says the wrong words -- a corrupted clip is a perfectly valid .m4a of the
wrong audio, and the only thing that noticed was a person listening.

Specifically it catches the schwa the voice model prepends when asked to
generate slowly ("Trace B" -> "a-Trace B", "Bee" -> "a B").

Speech recognition is not reliable enough to demand exact matches, especially
on one-syllable clips -- "Bee." has come back as "Be", "Zebay" and "I'll be".
So this reports two things and leaves judgement to a human:

  ARTICLE  the transcript starts with a/uh/at and the intended text does not.
           This is the artifact, and it is the signal worth acting on.
  DIFF     low word overlap. Noisy on short clips; useful in bulk.
"""

import argparse
import re
import sys
import warnings
from pathlib import Path

warnings.filterwarnings("ignore")
sys.path.insert(0, str(Path(__file__).parent))


def display_text(text):
    """Strip the phoneme markup so `[A](/ˈeɪ/) is for Apple.` reads as words."""
    return re.sub(r"\[([^\]]+)\]\(/[^/]*/\)", r"\1", text)


def intended_texts():
    """{clip key: what it should say} for both phases."""
    import gen_clips
    import gen_phase_b

    texts = {}
    for stem, text in gen_clips.clips():
        texts[stem] = display_text(text)
    for key, text in gen_phase_b.clips():
        texts[key] = display_text(text)
    return texts


def normalise(text):
    text = text.lower().replace("’", "'")
    text = re.sub(r"[^a-z0-9' ]+", " ", text)
    return " ".join(text.split())


LEADING_ARTICLES = ("a ", "uh ", "at ", "ah ")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("clips_dir")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--model", default="base.en")
    args = parser.parse_args()

    import whisper

    clips_dir = Path(args.clips_dir)
    texts = intended_texts()
    files = sorted(clips_dir.glob("*.m4a"))
    if args.limit:
        files = files[: args.limit]

    model = whisper.load_model(args.model)
    articles, diffs, unknown = [], [], []

    for index, path in enumerate(files, start=1):
        intended = texts.get(path.stem)
        if intended is None:
            unknown.append(path.stem)
            continue

        heard = model.transcribe(str(path), fp16=False, language="en")["text"]
        want, got = normalise(intended), normalise(heard)

        if got.startswith(LEADING_ARTICLES) and not want.startswith(LEADING_ARTICLES):
            articles.append((path.stem, intended, heard.strip()))
        else:
            want_words, got_words = set(want.split()), set(got.split())
            if want_words:
                overlap = len(want_words & got_words) / len(want_words)
                if overlap < 0.5:
                    diffs.append((path.stem, intended, heard.strip(), overlap))

        if index % 100 == 0:
            print(f"  {index}/{len(files)}  (articles: {len(articles)})", flush=True)

    print(f"\nchecked {len(files)} clips in {clips_dir}")
    print(f"  leading-article artifacts: {len(articles)}")
    print(f"  low word overlap:          {len(diffs)}")
    if unknown:
        print(f"  no intended text known:    {len(unknown)} (e.g. {unknown[:3]})")

    for stem, intended, heard in articles[:30]:
        print(f"  ARTICLE  {stem:34s} want {intended!r:34s} heard {heard!r}")
    if len(articles) > 30:
        print(f"  ... and {len(articles) - 30} more")

    for stem, intended, heard, overlap in sorted(diffs, key=lambda row: row[3])[:15]:
        print(f"  DIFF     {stem:34s} want {intended!r:34s} heard {heard!r}")
    if len(diffs) > 15:
        print(f"  ... and {len(diffs) - 15} more")

    # NOTE ON WHAT THIS DOES NOT COVER.
    #
    # The one-syllable clips (letter-<X>-name, -phoneme) are where the
    # prepended-schwa artifact did the most damage, and nothing here can judge
    # them. Transcription is unusable at that length -- "Bee." has come back as
    # "Be", "Zebay" and "I'll be" -- so both checks above are noise on those
    # files.
    #
    # A relative duration test was tried and removed: the artifact is prepended
    # to *every* clip in a family, so it lifts the median with the outliers and
    # the comparison sees nothing. Run against known-corrupted clips it found
    # only "letter-W-name", which is a false positive ("Double you" really is
    # longer than its peers). A check that reports clean on broken audio is
    # worse than no check, because it gets believed.
    #
    # The single-letter clips need a person to listen to them.
    print()
    print("  NOT CHECKED: letter-<X>-name / -phoneme — too short to transcribe")
    print("               reliably. Listen to those.")

    return 1 if articles else 0


if __name__ == "__main__":
    sys.exit(main())
