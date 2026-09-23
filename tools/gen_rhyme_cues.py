#!/usr/bin/env python3
"""Work out when each lyric line is sung, so the rhyme screen can follow along.

    ./venv/bin/python tools/gen_rhyme_cues.py                      # all rhymes
    ./venv/bin/python tools/gen_rhyme_cues.py --only twinkle       # one, by id/file fragment
    ./venv/bin/python tools/gen_rhyme_cues.py --show-unmatched     # what the singer sang that our lyrics don't cover

Writes `<audio file stem>.json` beside each recording in Resources/RhymeAudio:

    {"audio_sha1": "...", "duration": 123.4, "cues": [[0.2, 0], [4.8, 1], ...]}

Each cue is [seconds, line index]. `RhymeCues` reads these at runtime and
`RhymeDetailViewModel` highlights the line of the latest cue reached.

WHY THIS EXISTS
---------------
The highlight used to divide playback progress evenly across the lyric lines,
which assumes every line takes the same time and that the recording sings each
line exactly once. Neither holds: `twinkleTwinkle` sings its six lines four
times over 123s, so an even split parked the highlight on line one for 20s
while the singer was most of the way through a second pass.

HOW
---
Real forced alignment against the lyrics we already display, so the shown text
stays correct (Whisper mishears sung words often enough that using its
transcript as the lyrics would put wrong words in front of a child):

1. Demucs strips the backing track. Whisper is markedly better on an isolated
   vocal than on a full mix, and the stems are cached so re-runs are cheap.
2. Whisper transcribes that stem with word-level timestamps. Transcripts are
   cached alongside the stems, so re-running after editing lyrics is quick.
3. A dynamic program splits the heard words into runs and labels each run with
   the lyric line it matches best (see `align`). Any line can be used any
   number of times, so a repeated verse needs no special handling.
4. Each run's first word becomes that line's cue.

`coverage` in the report is the share of heard words that matched a lyric. A
low number means the recording sings something the lyrics don't cover -- an
extra verse, a countdown continuing past where the lyrics stop -- and the fix
is to author the missing lines, not to touch the alignment. Run with
--show-unmatched to see what was sung there.
"""

import argparse
import difflib
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CONTENT = REPO / "ToddlerLearningApp" / "Content" / "RhymeContent.swift"
AUDIO_DIR = REPO / "ToddlerLearningApp" / "Resources" / "RhymeAudio"

# Whisper hears a word a beat after it starts when the note is held, and a
# highlight that lands early reads as "the next line is coming" rather than as
# a mistake, so cues are nudged back slightly.
CUE_LEAD = 0.15

# Two cues for the same line closer together than this are one line, heard
# twice -- keep the first.
MIN_CUE_GAP = 0.4

# How much of a line has to be recognised before that stretch of audio counts
# as that line. Half allows for Whisper mishearing sung words, which it does
# often; much lower and unrelated audio starts matching short lines.
MIN_LINE_MATCH = 0.5

# How alike two spellings must be to count as the same word -- see `alike`.
FUZZY_RATIO = 0.75


def parse_rhymes() -> list[dict]:
    """(id, audioFileName, lines) for every rhyme, read from the Swift source.

    Parsed rather than duplicated here: a second copy of the lyrics would drift
    from the app's, which is exactly the failure check_content_sync.py exists
    to catch elsewhere.
    """
    source = CONTENT.read_text()
    rhymes = []
    for block in re.findall(r"Rhyme\(\s*(.*?)\n        \)", source, re.S):
        rhyme_id = re.search(r'id:\s*"([^"]+)"', block)
        audio = re.search(r'audioFileName:\s*"([^"]+)"', block)
        lines_block = re.search(r"lines:\s*\[(.*?)\n            \]", block, re.S)
        if not (rhyme_id and audio and lines_block):
            continue
        lines = re.findall(r'"((?:[^"\\]|\\.)*)"', lines_block.group(1))
        rhymes.append({
            "id": rhyme_id.group(1),
            "audio": audio.group(1),
            "lines": [line.replace('\\"', '"') for line in lines],
        })
    return rhymes


def duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
        capture_output=True, check=True, text=True,
    ).stdout
    return float(out.strip())


def vocal_stem(path: Path, cache: Path) -> Path:
    """Demucs vocals for one track, reused if it's already been separated.

    Keyed on the recording's own hash, not just its name: re-trimming a track
    shifts every timestamp in it, and a stem cached under the old audio would
    hand back cues that are silently seconds out.
    """
    folder = cache / "htdemucs" / path.stem
    stem = folder / "vocals.wav"
    fingerprint = folder / "source.sha1"
    digest = hashlib.sha1(path.read_bytes()).hexdigest()

    if stem.exists() and fingerprint.exists() and fingerprint.read_text().strip() == digest:
        return stem

    if folder.exists():
        shutil.rmtree(folder)
    subprocess.run(
        [sys.executable, "-m", "demucs", "--two-stems=vocals", "-o", str(cache), str(path)],
        check=True,
    )
    fingerprint.write_text(digest + "\n")
    return stem


def tokenize(text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", text.lower())


def heard_words(model, stem: Path) -> list[tuple[str, float]]:
    """(word, start time) for everything sung, from Whisper's word timestamps.

    Cached beside the stem: transcription is the slow half of a run, and the
    lyrics get edited and realigned several times before they cover a
    recording properly.
    """
    cached = stem.with_name("heard.json")
    if cached.exists():
        return [(word, time) for word, time in json.loads(cached.read_text())]

    result = model.transcribe(str(stem), word_timestamps=True, fp16=False)
    words = []
    for segment in result["segments"]:
        for word in segment.get("words", []):
            for token in tokenize(word["word"]):
                words.append((token, word["start"]))
    cached.write_text(json.dumps(words))
    return words


def soundex(word: str) -> str:
    """Crude phonetic key, enough to tell that two spellings sound alike."""
    codes = {**dict.fromkeys("bfpv", "1"), **dict.fromkeys("cgjkqsxz", "2"),
             **dict.fromkeys("dt", "3"), "l": "4", **dict.fromkeys("mn", "5"), "r": "6"}
    if not word:
        return ""
    digits = []
    previous = codes.get(word[0], "")
    for letter in word[1:]:
        code = codes.get(letter, "")
        if code and code != previous:
            digits.append(code)
        if letter not in "hw":
            previous = code
    return (word[0] + "".join(digits) + "000")[:4]


def alike(heard: set[str], lyrics: set[str]) -> set[tuple[str, str]]:
    """Which heard words may stand in for which lyric words.

    Whisper transcribes singing, not speech, and mangles it constantly: this
    pack's Ring a Ring o' Roses comes back as "rosy s", "bozies" and "a
    tissue". Demanding exact spellings dropped the "A-tishoo!" line entirely --
    it earned no cue, so the highlight skipped from the posies straight to
    falling down. A word therefore also counts when the spellings are close,
    or when they simply sound the same (tishoo / tissue).

    Computed once per song over the distinct words, since the alignment asks
    this question a few million times.
    """
    return {(word, token) for word in heard for token in lyrics
            if similar(word, token)}


def similar(word: str, token: str) -> bool:
    """Whether a heard word can stand in for a lyric word."""
    return (word == token
            or difflib.SequenceMatcher(None, word, token).ratio() >= FUZZY_RATIO
            or (len(word) >= 4 and len(token) >= 4 and soundex(word) == soundex(token)))


def repair_splits(heard: list[tuple[str, float]],
                   lyric_tokens: list[list[str]]) -> list[tuple[str, float]]:
    """Rejoin words Whisper split in a different place than the lyrics do.

    Whisper hears "A-tishoo!" as "at issue" -- two words, neither of which
    resembles either lyric word, so the line matched nothing and never earned
    a cue. Where a heard word matches no lyric word on its own but joins with
    the next one to sound like a lyric pair, the pair is taken as sung. The
    lyrics supply the spelling; the audio keeps its timings.
    """
    pairs = {first + second: (first, second)
             for tokens in lyric_tokens for first, second in zip(tokens, tokens[1:])}
    singles = {token for tokens in lyric_tokens for token in tokens}

    repaired: list[tuple[str, float]] = []
    index = 0
    while index < len(heard):
        word, time = heard[index]
        if index + 1 < len(heard) and not any(similar(word, token) for token in singles):
            joined = word + heard[index + 1][0]
            match = next((pair for key, pair in pairs.items() if similar(joined, key)), None)
            if match:
                repaired.append((match[0], time))
                repaired.append((match[1], heard[index + 1][1]))
                index += 2
                continue
        repaired.append((word, time))
        index += 1
    return repaired


def token_weights(lyric_tokens: list[list[str]]) -> dict[str, float]:
    """How much matching each word tells us that we're on a given line.

    "Posies" appears in one line of Ring a Ring o' Roses and pins it exactly;
    "a" appears all over and pins nothing. Weighting by how rare a word is in
    the song stops a line being claimed on its filler words alone -- which put
    an "A-tishoo!" cue halfway through the first line, because two stray "a"s
    were half of that line's words.
    """
    counts: dict[str, int] = {}
    for tokens in lyric_tokens:
        for token in set(tokens):
            counts[token] = counts.get(token, 0) + 1
    return {token: 1.0 / count for token, count in counts.items()}


def line_scores(words: list[str], start: int, tokens: list[str], longest: int,
                 weights: dict[str, float], matches: set[tuple[str, str]]) -> list[float]:
    """How well `tokens` matches the heard words from `start`, per span length.

    Entry s is the weight of the in-order matches between `tokens` and the s
    heard words beginning at `start` — a longest-common-subsequence, so a
    dropped or mangled word costs that word rather than derailing the rest.
    All span lengths come out of one pass: extending the span by a word is
    just another row of the same table.
    """
    width = len(tokens)
    row = [0.0] * (width + 1)
    scores = [0.0] * (longest + 1)
    for span in range(1, longest + 1):
        word = words[start + span - 1]
        previous = row[:]
        for column, token in enumerate(tokens, 1):
            row[column] = (previous[column - 1] + weights.get(token, 1.0)
                           if (word, token) in matches
                           else max(previous[column], row[column - 1]))
        scores[span] = row[width]
    return scores


def align(heard: list[tuple[str, float]], lines: list[str]) -> tuple[list[list], float]:
    """(cues, coverage) — cues are [time, line index], in playback order.

    Splits the heard words into consecutive runs, each labelled with the lyric
    line it best matches, choosing the split that matches the most words
    overall. Any line may be labelled any number of times, which is what makes
    a repeated verse work: a second pass is simply the same labels again.

    Solved as a dynamic program from the end backwards, so the choice at each
    word accounts for everything after it — a greedy left-to-right match would
    latch onto the first plausible line and drift out of step on the repeats.
    """
    lyric_tokens = [tokenize(line) for line in lines]
    heard = repair_splits(heard, lyric_tokens)
    words = [word for word, _ in heard]
    times = [time for _, time in heard]
    total = len(words)
    weights = token_weights(lyric_tokens)
    matches = alike(set(words), {token for tokens in lyric_tokens for token in tokens})
    line_weight = [sum(weights.get(token, 1.0) for token in tokens) or 1.0
                   for tokens in lyric_tokens]

    best = [0.0] * (total + 1)
    # (span, line index) chosen at each position, or None to skip a word that
    # belongs to no line -- ad-libs, or Whisper mishearing the backing track.
    choice: list[tuple[int, int] | None] = [None] * (total + 1)

    for position in range(total - 1, -1, -1):
        best_score = best[position + 1]
        best_choice = None
        for index, tokens in enumerate(lyric_tokens):
            if not tokens:
                continue
            longest = min(total - position, int(len(tokens) * 1.8) + 2)
            shortest = max(1, len(tokens) // 2)
            scores = line_scores(words, position, tokens, longest, weights, matches)
            for span in range(shortest, longest + 1):
                # Too little of the line recognised to call it sung here.
                if scores[span] < MIN_LINE_MATCH * line_weight[index]:
                    continue
                score = scores[span] + best[position + span]
                if score > best_score:
                    best_score = score
                    best_choice = (span, index)
        best[position] = best_score
        choice[position] = best_choice

    cues: list[list] = []
    matched = 0.0
    position = 0
    while position < total:
        picked = choice[position]
        if picked is None:
            position += 1
            continue
        span, index = picked
        # Counted unweighted, and against the words actually heard: coverage
        # answers "how much of this recording do the lyrics account for", so
        # the rarity weighting that decides *which* line wins has no business
        # in it -- it was scoring some recordings over 100%.
        matched += line_scores(words, position, lyric_tokens[index], span, {}, matches)[span]
        start = max(0.0, times[position] - CUE_LEAD)
        if not (cues and cues[-1][1] == index and start - cues[-1][0] < MIN_CUE_GAP):
            cues.append([round(start, 2), index])
        position += span

    settle_repeats(cues, lyric_tokens)
    coverage = matched / total if total else 0.0
    return cues, coverage


def settle_repeats(cues: list[list], lyric_tokens: list[list[str]]):
    """Point each cue at the copy of its line that the song has reached.

    A refrain is often written out once per verse -- "All through the town."
    appears seven times in The Wheels on the Bus, "My fair lady." six times in
    London Bridge -- and those copies are identical, so the match above scores
    them all the same and takes the first. The highlight would then jump back
    to verse one at the end of every verse. Nothing in the audio can tell the
    copies apart, so position does: take whichever copy follows on from the
    line before it.
    """
    copies: dict[str, list[int]] = {}
    for index, tokens in enumerate(lyric_tokens):
        copies.setdefault(" ".join(tokens), []).append(index)

    count = len(lyric_tokens)
    expected = 0
    for cue in cues:
        options = copies[" ".join(lyric_tokens[cue[1]])]
        if len(options) > 1:
            # Circular, so the last line running back round to the first is
            # near rather than furthest away.
            cue[1] = min(options, key=lambda index: min((index - expected) % count,
                                                        (expected - index) % count))
        expected = (cue[1] + 1) % count


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", action="append", default=[],
                         help="only rhymes whose id or audio file contains this (repeatable)")
    parser.add_argument("--cache", type=Path, default=Path("/tmp/rhyme_stems"),
                         help="where demucs stems are kept between runs")
    parser.add_argument("--model", default="small",
                         help="Whisper model (default: small — base mishears sung words badly)")
    parser.add_argument("--show-unmatched", action="store_true",
                         help="print what was sung that the lyrics don't cover")
    args = parser.parse_args()

    rhymes = parse_rhymes()
    if args.only:
        rhymes = [r for r in rhymes
                  if any(f in r["id"] or f in r["audio"] for f in args.only)]
    if not rhymes:
        sys.exit("no rhymes matched")

    import whisper
    model = whisper.load_model(args.model)

    print(f"\n{len(rhymes)} rhyme(s)\n")
    weak = []
    for rhyme in rhymes:
        path = AUDIO_DIR / rhyme["audio"]
        if not path.exists():
            print(f"  {rhyme['id']:34s} NO AUDIO ({rhyme['audio']})")
            continue

        stem = vocal_stem(path, args.cache)
        heard = heard_words(model, stem)
        cues, coverage = align(heard, rhyme["lines"])

        total = duration(path)
        out_path = path.with_suffix(".json")
        out_path.write_text(json.dumps({
            "audio_sha1": hashlib.sha1(path.read_bytes()).hexdigest(),
            "duration": round(total, 3),
            "cues": cues,
        }) + "\n")

        flag = "" if coverage >= 0.75 else "   <-- lyrics miss part of this recording"
        print(f"  {rhyme['id']:34s} {len(cues):3d} cues  coverage {coverage:5.0%}{flag}")
        if coverage < 0.75:
            weak.append(rhyme["id"])

        if args.show_unmatched:
            matcher = difflib.SequenceMatcher(
                a=[w for w, _ in heard],
                b=[t for line in rhyme["lines"] for t in tokenize(line)],
                autojunk=False,
            )
            for tag, i1, i2, _, _ in matcher.get_opcodes():
                if tag in ("replace", "delete") and i2 - i1 >= 4:
                    span = " ".join(w for w, _ in heard[i1:i2])
                    print(f"      unmatched {heard[i1][1]:6.1f}s: {span[:110]}")

    print()
    if weak:
        print(f"{len(weak)} rhyme(s) whose lyrics don't cover the recording: {', '.join(weak)}")
        print("Author the missing lines in RhymeContent.swift, then re-run.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
