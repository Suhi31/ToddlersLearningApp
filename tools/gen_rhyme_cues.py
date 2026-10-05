#!/usr/bin/env python3
"""Work out when each lyric line is sung, so the rhyme screen can follow along.

    ./venv/bin/python tools/gen_rhyme_cues.py                      # all rhymes
    ./venv/bin/python tools/gen_rhyme_cues.py --only twinkle       # one, by id/file fragment
    ./venv/bin/python tools/gen_rhyme_cues.py --show-unmatched     # what the singer sang that our lyrics don't cover

Writes `<audio file stem>.json` beside each recording in Resources/RhymeAudio:

    {"audio_sha1": "...", "lyrics_sha1": "...", "duration": 123.4,
     "cues": [[0.2, 0], [4.8, 1], ...]}

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
2. Whisper transcribes that stem with word-level timestamps, one overlapping
   10-second window at a time (see `heard_words` for why). Transcripts are
   cached alongside the stems, so re-running after editing lyrics is quick.
3. A dynamic program splits the heard words into runs and labels each run with
   the lyric line it matches best (see `align`). Any line can be used any
   number of times, so a repeated verse needs no special handling.
4. The first word of each run that the line actually matched becomes its cue.
5. Lines the transcript lost -- Whisper drops words, and a garbled name or a
   skipped stretch leaves a line with nothing to match -- are found by asking
   Whisper's decoder where in the gap between their neighbours each would fit
   best (see `fill_gaps`). A line with nothing to sing at all -- the all-claps
   verse of B-I-N-G-O, written with clap emoji -- is cued from the singing
   around it instead (see `cue_silent_lines`).

A rhyme whose cues come out too thin to be useful gets no sidecar at all --
see MIN_LINES_CUED. The app then spreads the lines evenly, which beats a
highlight that never moves.

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

# Cues this thin are worse than none: the app's even-split fallback at least
# moves. Whisper sometimes transcribes only the opening phrase of a short clip
# and then nothing — the trimmed Happy Birthday came back as four words across
# twelve seconds of singing, which pinned the highlight to line one for the
# whole song.
MIN_LINES_CUED = 0.5
MIN_CUE_SPAN = 0.5

# Whisper transcribes a whole song as one long sequence, and in songs this
# repetitive it loses its place: it skipped ~30s of The Wheels on the Bus
# (wipers and baby verses), came back with four words for a twelve-second
# Happy Birthday, and drifted into "roll over" loops in Ten in the Bed. Short
# independent windows can't do that -- each is decoded cold, with no earlier
# text to repeat. Each window contributes only the words sitting in its middle
# HOP seconds, where the model has context either side of them.
SAMPLE_RATE = 16000
WINDOW = 10.0
HOP = 5.0

# A hallucinated loop ("where where where ...", "roll over roll over ...") is
# dozens of words in a window's worth of audio. Even fast sung syllables ("wah
# wah wah") stay well under five a second, so anything beyond that is thrown
# away. Runs that repeat more than a song ever does -- six "swish"es is the
# most any of these rhymes sings in a row -- are cut back to what a song might.
MAX_WORDS_PER_SLICE = 24
MAX_REPEATS = {1: 8, 2: 6, 3: 5}   # by length of the repeating unit, in words

# How long a heard word is assumed to last, for finding where a line ended.
WORD_SECONDS = 0.6

# What each unheard word of a matched line costs, relative to what a heard one
# earns -- see `align`.
UNHEARD_PENALTY = 0.5

# Words that must have matched before a run counts as a line at all (a line
# shorter than this needs all of its words).
MIN_WORDS_HEARD = 2

# Looking for a line the matcher missed (`fill_gaps`): how far apart the
# candidate start times are, how long after the previous line began the search
# starts, and how far the best candidate must stand above a typical one before
# it is believed -- in log-probability points.
SWEEP_STEP = 0.5
SWEEP_LEAD = 1.0
MIN_PEAK = 4.0

# A step back to an earlier line that is over this quickly -- and then goes on
# past where it started -- is a mislabel; see `drop_flickers`.
FLICKER_SECONDS = 1.6

# How soon after a line ends the same words count as the line still going. A
# real second singing of an identical line starts a breath after the first
# stops; an echo starts before it.
ECHO_SLACK = 0.25


def parse_rhymes() -> list[dict]:
    """(id, audioFileName, lines) for every rhyme, read from the Swift source.

    Parsed rather than duplicated here: a second copy of the lyrics would drift
    from the app's, which is exactly the failure check_content_sync.py exists
    to catch elsewhere.
    """
    source = CONTENT.read_text(encoding="utf-8")
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


def lyrics_digest(lines: list[str]) -> str:
    """Fingerprint of the words in a rhyme's lyrics, written into its sidecar.

    The cues are only valid for the lyrics they were aligned against -- insert a
    verse and every later line index is wrong, and nothing in the build notices.
    Stamped beside `audio_sha1`, which does the same job for the recording, so
    anything that cares can tell stale cues from fresh ones. Words only, not
    punctuation or capitals: fixing a comma doesn't move any cue. Anything
    recomputing it must tokenize the way `tokenize` does.
    """
    words = "\n".join(" ".join(tokenize(line)) for line in lines)
    return hashlib.sha1(words.encode("utf-8")).hexdigest()


def drop_loops(words: list[tuple[str, float]]) -> list[tuple[str, float]]:
    """Cut runaway repetition back to a plausible number of repeats."""
    for period, limit in MAX_REPEATS.items():
        kept: list[tuple[str, float]] = []
        index = 0
        while index < len(words):
            unit = [word for word, _ in words[index:index + period]]
            repeats = 1
            if len(unit) == period:
                while [word for word, _ in
                       words[index + repeats * period: index + (repeats + 1) * period]] == unit:
                    repeats += 1
            if repeats > limit:
                kept.extend(words[index: index + limit * period])
                index += repeats * period
            else:
                kept.append(words[index])
                index += 1
        words = kept
    return words


def heard_words(model, model_name: str, stem: Path) -> list[tuple[str, float]]:
    """(word, start time) for everything sung, from Whisper's word timestamps.

    Cached beside the stem: transcription is the slow half of a run, and the
    lyrics get edited and realigned several times before they cover a
    recording properly. The cache is keyed on the model and window settings
    as well as the stem, so changing either re-transcribes rather than
    silently reusing the other's words.
    """
    import whisper

    cached = stem.with_name(f"heard_{model_name}_w{WINDOW:g}_{HOP:g}.json")
    if cached.exists():
        return drop_loops([(word, time) for word, time in json.loads(cached.read_text())])

    audio = whisper.load_audio(str(stem))
    total = len(audio) / SAMPLE_RATE
    words: list[tuple[str, float]] = []
    start = 0.0
    while start < total - 0.3:
        window = audio[int(start * SAMPLE_RATE): int((start + WINDOW) * SAMPLE_RATE)]
        # The first and last windows have no neighbour on one side, so they
        # keep their edge.
        keep_from = start if start == 0.0 else start + (WINDOW - HOP) / 2
        keep_to = float("inf") if start + WINDOW >= total else start + (WINDOW + HOP) / 2

        # Temperature 0 and no fallback: a window that decodes badly should
        # say so, not be retried hotter until it says something plausible.
        result = model.transcribe(window, language="en", word_timestamps=True,
                                  fp16=False, temperature=0.0,
                                  condition_on_previous_text=False,
                                  no_speech_threshold=0.99, logprob_threshold=-5.0,
                                  compression_ratio_threshold=10.0)
        kept = []
        for segment in result["segments"]:
            for word in segment.get("words", []):
                begin = start + word["start"]
                if keep_from <= begin < keep_to:
                    kept.extend((token, begin) for token in tokenize(word["word"]))
        words.extend(kept[:MAX_WORDS_PER_SLICE])
        start += HOP

    # The raw words are cached; `drop_loops` is applied on the way out, so
    # retuning it doesn't mean transcribing the whole library again.
    cached.write_text(json.dumps(words))
    return drop_loops(words)


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

    A heard word that is itself one of the lyric words is taken at face value
    and only matches itself: Whisper writing "there" is not mishearing "three",
    it is a word the song also uses. Only words the lyrics don't contain are
    fuzzy-matched to the nearest ones that they do. (Without this, every
    "there were" in Ten in the Bed scored as the heavily weighted "three".)

    Computed once per song over the distinct words, since the alignment asks
    this question a few million times.
    """
    return {(word, token) for word in heard for token in lyrics
            if word == token or (word not in lyrics and similar(word, token))}


# Letter names Whisper writes out as words. Only "bee" is needed so far: it is
# what B-I-N-G-O's first letter comes back as, and without it the verse that
# sings "B" matched the verse that doesn't.
SPELLED_LETTERS = {"be": "b", "bee": "b"}


def similar(word: str, token: str) -> bool:
    """Whether a heard word can stand in for a lyric word."""
    if word == token or SPELLED_LETTERS.get(word) == token:
        return True
    # Whisper spells the "-o" of "name-o" as "oh" about as often as "o" -- and
    # at one and two letters they share too little for the ratio below. Left
    # unmatched, B-I-N-G-O's closing line fell under half a match and was never
    # cued.
    if len(word) <= 2 and len(token) <= 2:
        return word.rstrip("h") == token.rstrip("h")
    # Beyond that, short words match only themselves. The similarity ratio
    # rates "the" and "three" at 0.75, so once Five Little Monkeys counted
    # down, every "the" in the song scored as the rare, heavily weighted
    # "three", and the matcher labelled "the doctor and" as the line "Three
    # little monkeys jumping on the bed". Likewise "the" for "he".
    if min(len(word), len(token)) < 4:
        return False
    return (difflib.SequenceMatcher(None, word, token).ratio() >= FUZZY_RATIO
            or soundex(word) == soundex(token))


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
        # The reverse split: one heard word where the lyrics have two. Ten in
        # the Bed ends "Good night!" and Whisper writes "goodnight", which
        # matches neither word, so the last line never got a cue.
        if word not in singles and word in pairs:
            first, second = pairs[word]
            repaired.append((first, time))
            repaired.append((second, time + 0.01))
            index += 1
            continue
        # Both halves have to be words the lyrics don't use: "at issue" is a
        # mis-split of "a-tishoo", but a stray "i" in front of a real "well"
        # is not -- it was being rejoined into "we'll" and swallowing the word.
        if (index + 1 < len(heard)
                and not any(similar(word, token) for token in singles)
                and not any(similar(heard[index + 1][0], token) for token in singles)):
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
                 weights: dict[str, float], matches: set[tuple[str, str]]
                 ) -> tuple[list[float], list[float], list[int]]:
    """How well `tokens` matches the heard words from `start`, per span length.

    `scores[s]` is the weight of the in-order matches between `tokens` and the
    s heard words beginning at `start` — a longest-common-subsequence, so a
    dropped or mangled word costs that word rather than derailing the rest.
    All span lengths come out of one pass: extending the span by a word is
    just another row of the same table.

    `hits[s]` is different: the weight of the *distinct* words of the line that
    those s words contain at all, however often. That is what says whether the
    line has been recognised -- a line that says "Brother finger" twice is
    recognised by hearing it once -- where `scores` says how much of the audio
    it explains.

    `counts[s]` is how many words matched, unweighted: a line of one repeated
    sound ("O! O! O!") has a single distinct word, which any stray "o" would
    recognise, so a run also has to have matched a couple of words.
    """
    width = len(tokens)
    distinct = set(tokens)
    found: set[str] = set()
    found_weight = 0.0
    row = [0.0] * (width + 1)
    tally = [0] * (width + 1)
    scores = [0.0] * (longest + 1)
    hits = [0.0] * (longest + 1)
    counts = [0] * (longest + 1)
    for span in range(1, longest + 1):
        word = words[start + span - 1]
        previous, previous_tally = row[:], tally[:]
        for column, token in enumerate(tokens, 1):
            if (word, token) in matches:
                row[column] = previous[column - 1] + weights.get(token, 1.0)
                tally[column] = previous_tally[column - 1] + 1
            else:
                row[column] = max(previous[column], row[column - 1])
                tally[column] = max(previous_tally[column], tally[column - 1])
        scores[span] = row[width]
        counts[span] = tally[width]
        for token in distinct - found:
            if (word, token) in matches:
                found.add(token)
                found_weight += weights.get(token, 1.0)
        hits[span] = found_weight
    return scores, hits, counts


def first_heard(words: list[str], start: int, span: int, tokens: list[str],
                weights: dict[str, float], matches: set[tuple[str, str]]) -> int:
    """Index of the first word that the best match of `tokens` actually uses.

    A run's span can begin with words that merely sit in front of the line --
    the matcher takes "the bed four" for the line "Four little monkeys jumping
    on the bed" because "four" is the word that identifies it, and the "the
    bed" ahead of it is just left-over from the line before. Cueing the span's
    first word would light the line up three seconds early; cueing the first
    word it *matched* lands where the line starts.
    """
    width = len(tokens)
    table = [[0.0] * (width + 1) for _ in range(span + 1)]
    for row in range(1, span + 1):
        word = words[start + row - 1]
        for column, token in enumerate(tokens, 1):
            table[row][column] = (table[row - 1][column - 1] + weights.get(token, 1.0)
                                  if (word, token) in matches
                                  else max(table[row - 1][column], table[row][column - 1]))
    row, column, first = span, width, start
    while row > 0 and column > 0:
        token = tokens[column - 1]
        if ((words[start + row - 1], token) in matches
                and table[row][column] == table[row - 1][column - 1] + weights.get(token, 1.0)):
            first = start + row - 1
            row -= 1
            column -= 1
        elif table[row - 1][column] >= table[row][column - 1]:
            row -= 1
        else:
            column -= 1
    return first


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
    # A line's weight counts each *distinct* word once. "Brother finger, Brother
    # finger, where are you?" is one introduction repeated for effect, and
    # Whisper hears the second "Brother finger" about half the time; counting
    # both made "brother" worth double, so hearing it once was never enough to
    # reach half the line and the verse went uncued. The same goes for "wah,
    # wah, wah" -- it is the one sound, not three words to find.
    line_weight = [sum(weights.get(token, 1.0) for token in set(tokens)) or 1.0
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
            scores, hits, counts = line_scores(words, position, tokens, longest, weights, matches)
            enough = min(MIN_WORDS_HEARD, len(tokens))
            for span in range(shortest, longest + 1):
                matched, heard_weight = scores[span], hits[span]
                # Too little of the line recognised to call it sung here.
                if heard_weight < MIN_LINE_MATCH * line_weight[index] or counts[span] < enough:
                    continue
                # A run is worth what it matched, less a penalty on what of
                # the line it did *not*. Matching alone only ever rewards, which
                # let the matcher cut one sung line in two and label each half
                # as a different line: "Five little monkeys | jumping on the
                # bed" scored the first half against line one and the second
                # against "Three little monkeys jumping on the bed", banking
                # more matched words than the whole line would -- and a song
                # of near-identical verses fell apart. It also scored "I-N-G-O"
                # sung three times the same against B-I-N-G-O (three B's never
                # heard) as against the line it actually is.
                score = (matched - UNHEARD_PENALTY * (line_weight[index] - heard_weight)
                         + best[position + span])
                if score > best_score:
                    best_score = score
                    best_choice = (span, index)
        best[position] = best_score
        choice[position] = best_choice

    cues: list[list] = []
    # When each cue's line stopped being sung, parallel to `cues` -- only
    # `cue_silent_lines` wants it.
    ends: list[float] = []
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
        matched += line_scores(words, position, lyric_tokens[index], span, {}, matches)[0][span]
        first = first_heard(words, position, span, lyric_tokens[index], weights, matches)
        start = max(0.0, times[first] - CUE_LEAD)
        end = times[position + span - 1] + WORD_SECONDS
        # Two runs of the same words back to back are one line heard twice --
        # Whisper repeats the tail of a held final note ("his name-o. his
        # name-o.") and the matcher dutifully labels the echo as a second
        # line. Compared by text, not index: the copies get told apart later.
        echo = bool(cues) and lyric_tokens[cues[-1][1]] == lyric_tokens[index] and (
            start - cues[-1][0] < MIN_CUE_GAP or start < ends[-1] + ECHO_SLACK)
        if echo:
            ends[-1] = max(ends[-1], end)
        else:
            cues.append([round(start, 2), index])
            ends.append(end)
        position += span

    settle_repeats(cues, lyric_tokens)
    cues = cue_silent_lines(cues, ends, lyric_tokens)
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
            # near rather than furthest away. Equally near, forward wins: a
            # song more often moves on than stutters -- and where a silent
            # line sits between two identical ones, forward is the only way to
            # tell them apart.
            cue[1] = min(options, key=lambda index: (
                min((index - expected) % count, (expected - index) % count),
                (index - expected) % count > (expected - index) % count))
        expected = (cue[1] + 1) % count


class Scorer:
    """Whisper's decoder as a judge of how well a line of text fits some audio.

    Teacher-forced: the text is fed to the decoder and every token's
    log-probability given the audio is summed. Unlike a transcript, this can be
    asked about a *specific* wording, so it answers "does this stretch sing
    that line?" even where Whisper's own transcription of it is garbled -- which
    is how `fill_gaps` finds lines the matcher missed.
    """

    def __init__(self, model, model_name: str):
        from whisper.tokenizer import get_tokenizer
        self.model = model
        multilingual = not model_name.endswith(".en")
        self.tokenizer = get_tokenizer(multilingual, language="en" if multilingual else None,
                                       task="transcribe")
        self.prefix = list(self.tokenizer.sot_sequence) + [self.tokenizer.no_timestamps]

    def mel(self, clip):
        import whisper
        return whisper.log_mel_spectrogram(whisper.pad_or_trim(clip),
                                           self.model.dims.n_mels).to(self.model.device)

    def features(self, clip):
        import torch
        with torch.no_grad():
            return self.model.encoder(self.mel(clip).unsqueeze(0))

    def log_prob(self, features, text: str) -> float:
        import torch
        ids = self.tokenizer.encode(" " + text.strip())
        sequence = torch.tensor([self.prefix + ids + [self.tokenizer.eot]],
                                device=self.model.device)
        with torch.no_grad():
            logits = self.model.decoder(sequence[:, :-1], features)
        logp = torch.log_softmax(logits.float(), dim=-1)[0]
        picked = logp.gather(1, sequence[0, 1:].unsqueeze(1)).squeeze(1)
        return picked[len(self.prefix) - 1:].sum().item()


def fill_gaps(cues: list[list], lines: list[str], lyric_tokens: list[list[str]],
              scorer: Scorer, audio, total: float) -> list[list]:
    """Cue the lines the matcher never found, by asking the model where they are.

    The matcher works from Whisper's *transcript*, and the transcript drops
    words: a quiet line, a garbled name, a stretch it skipped. Brother's
    verse of Finger Family came back as "finger brother finger?" and Hush
    Little Baby's diamond ring as nothing at all, so those lines never got a
    cue and the highlight sat on the line before while they were sung.

    A line that is missing is still *somewhere*: between the cues of the lines
    on either side of it. Each candidate start inside that gap is scored with
    the line's own text, and the start that fits clearly best is taken. A line
    nothing fits (a verse the recording turns out not to sing, or sound effects
    where it should be) is left uncued rather than guessed at.
    """
    cued = {line for _, line in cues}
    missing = [index for index, tokens in enumerate(lyric_tokens) if tokens and index not in cued]
    if not missing:
        return cues

    runs: list[list[int]] = []
    for index in missing:
        if runs and index == runs[-1][-1] + 1:
            runs[-1].append(index)
        else:
            runs.append([index])

    # Sentinels let a run before the first cue or after the last one be
    # bracketed like any other.
    framed = [[0.0, -1]] + sorted(cues) + [[total, len(lines)]]
    added: list[list] = []
    for run in runs:
        pairs = [(framed[i], framed[i + 1]) for i in range(len(framed) - 1)
                 if framed[i][1] < run[0] and framed[i + 1][1] > run[-1]]
        if not pairs:
            continue
        # The tightest bracket, then the roomiest: neighbouring lines, if the
        # song has them, rather than a distant verse.
        before, after = min(pairs, key=lambda pair: (pair[1][1] - pair[0][1],
                                                     -(pair[1][0] - pair[0][0])))
        low = before[0] + (SWEEP_LEAD if before[1] >= 0 else 0.0)
        high = after[0] - 0.3

        for index in run:
            tokens = lyric_tokens[index]
            # Roughly how long the line takes to sing.
            length = min(max(0.5 * len(tokens) + 0.8, 1.6), 7.0)
            results = []
            start = low
            while start + 1.0 <= high:
                clip = audio[int(max(0.0, start - 0.1) * SAMPLE_RATE):
                             int(min(total, start + length + 0.4) * SAMPLE_RATE)]
                results.append((scorer.log_prob(scorer.features(clip), lines[index]), start))
                start += SWEEP_STEP
            if not results:
                continue
            best_score, best_start = max(results)
            typical = sorted(score for score, _ in results)[len(results) // 2]
            if best_score < typical + MIN_PEAK:
                continue
            added.append([round(best_start, 2), index])
            low = best_start + 1.0   # the next missing line comes after this one
    return sorted(cues + added)


def drop_flickers(cues: list[list]) -> list[list]:
    """Remove a cue that sends the highlight back a line for an instant.

    Ten in the Bed's first verse came out cued line 3, line 2, line 4: while the
    singer ran straight on, "so they all rolled over / and one fell out", the
    highlight flashed back to "Roll over, roll over!" for a second. A real
    return to an earlier line -- a verse sung through again -- lasts a line, not
    a breath, so a step back that is over in `FLICKER_SECONDS` and then carries on
    past where it left is a mislabel, not the singer going back.

    Run last, after `fill_gaps`: the line that carries on past it is often one
    that only gap-filling found.
    """
    kept = cues[:1]
    for index in range(1, len(cues) - 1):
        before, here, after = kept[-1], cues[index], cues[index + 1]
        if not (here[1] < before[1] < after[1] and after[0] - here[0] < FLICKER_SECONDS):
            kept.append(here)
    return kept + cues[len(cues) - 1:] if len(cues) > 1 else kept


def cue_silent_lines(cues: list[list], ends: list[float],
                     lyric_tokens: list[list[str]]) -> list[list]:
    """Cue the lines that have no words, from the singing on either side.

    B-I-N-G-O's last verse is five claps, three times over. Written with clap
    emoji the line has nothing for the matcher to find, so it could never be
    picked and the highlight would sit on the line before while the whole room
    clapped. A silent line runs from where the line before it stops to where
    the next sung line begins, so it is cued at the first -- and shares the
    gap with any other silent line in between.
    """
    silent = [not tokens for tokens in lyric_tokens]
    if not any(silent):
        return cues

    result: list[list] = []
    for number, cue in enumerate(cues):
        result.append(cue)
        if number + 1 == len(cues):
            continue
        following = cues[number + 1]
        between = list(range(cue[1] + 1, following[1]))
        if not between or not all(silent[line] for line in between):
            continue
        # Never later than half a second before the next line, nor before this
        # one began: a cue crammed against its neighbour would never be seen.
        begin = max(cue[0] + MIN_CUE_GAP, min(ends[number], following[0] - 0.5))
        share = (following[0] - begin) / len(between)
        for step, line in enumerate(between):
            result.append([round(begin + step * share, 2), line])
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", action="append", default=[],
                         help="only rhymes whose id or audio file contains this (repeatable)")
    parser.add_argument("--cache", type=Path, default=Path("/tmp/rhyme_stems"),
                         help="where demucs stems are kept between runs")
    parser.add_argument("--model", default="small.en",
                         help="Whisper model (default: small.en -- base mishears sung words "
                              "badly, and every recording here is English)")
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
    scorer = Scorer(model, args.model)

    print(f"\n{len(rhymes)} rhyme(s)\n")
    weak = []
    for rhyme in rhymes:
        path = AUDIO_DIR / rhyme["audio"]
        if not path.exists():
            print(f"  {rhyme['id']:34s} NO AUDIO ({rhyme['audio']})")
            continue

        stem = vocal_stem(path, args.cache)
        heard = heard_words(model, args.model, stem)
        cues, coverage = align(heard, rhyme["lines"])

        total = duration(path)
        cues = drop_flickers(fill_gaps(cues, rhyme["lines"],
                                       [tokenize(line) for line in rhyme["lines"]],
                                       scorer, whisper.load_audio(str(stem)), total))
        out_path = path.with_suffix(".json")

        # Refuse to ship cues that would hold the highlight still. Removing the
        # sidecar is the signal: `RhymeCues.load` returns nil and the detail
        # screen spreads the lines evenly instead, which is roughly right for a
        # short single-pass recording.
        lines_cued = len({line for _, line in cues})
        span = (cues[-1][0] / total) if cues and total > 0 else 0.0
        if lines_cued < len(rhyme["lines"]) * MIN_LINES_CUED or span < MIN_CUE_SPAN:
            out_path.unlink(missing_ok=True)
            print(f"  {rhyme['id']:34s} {len(cues):3d} cues  coverage {coverage:5.0%}"
                  f"   <-- too thin to use; falling back to an even split")
            continue

        out_path.write_text(json.dumps({
            "audio_sha1": hashlib.sha1(path.read_bytes()).hexdigest(),
            "lyrics_sha1": lyrics_digest(rhyme["lines"]),
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
