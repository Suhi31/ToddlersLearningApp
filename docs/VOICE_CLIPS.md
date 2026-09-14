# Voice clips

The app's spoken lines are **pre-generated audio files**, not synthesised
speech. They are produced on a dev Mac with
[Kokoro](https://github.com/hexgrad/kokoro) (Apache-2.0) and bundled as `.m4a`.

Anything without a clip still falls through to `SpeechService`
(`AVSpeechSynthesizer`) — see `RecordedSpeechService`. Nothing from the
generation pipeline ships inside the app; the app only ever sees audio files.

## Choosing the voice

One compile-time flag in `AppDependencies`: `usesRecordedVoice`. `true` (the
default) plays the bundled clips everywhere; `false` synthesizes everything, as
the app sounded before the recordings existed. Set, rebuild, done — both paths
are `SpeechServicing` and every screen talks to that protocol.

## Counting timings

Learn Numbers lights up each object as its number is said. The synthesizer
knows when that is because it speaks each number separately; a recording of
"One, two, three." is a single file, so each counting clip carries a sidecar
`number-<N>-counting.json` with the moment every number starts.
`RecordedSpeechService` fires the highlight as playback reaches each one.

```bash
./venv/bin/python tools/gen_count_timings.py    # all of VoiceClips/, then tools/use_voice.sh
```

The timings come from Kokoro itself, not from listening to the clip: the line
is generated again, the copy's word timestamps are kept and the copy is thrown
away. That only works because Kokoro's *durations* are deterministic even
though its waveform is not — a fresh copy's speech matches the shipped clip's
length to within ~10ms, and the tool refuses any clip that doesn't match.
Whisper word timestamps were tried first and were off by up to ~130ms.

Each timing file records the SHA-1 of the clip it was measured from, so
**re-rolling a counting clip means re-running this** — `check_keys.py` fails
until you do. A missing timing file doesn't break anything at runtime: the
count plays with nothing lit.

## Layout

```
VoiceClips/<voice>/*.m4a                every generated voice — NOT in the app target
ToddlerLearningApp/Resources/Speech/    the one voice currently bundled
```

`Resources/Speech/` is inside the app folder, so Xcode's synchronized group
picks it up automatically and the files land flat in the bundle, which is what
`Bundle.main.url(forResource:withExtension:)` looks for. Swapping voices needs
no project-file edit and no code change.

```bash
tools/use_voice.sh              # list voices, and show which is bundled
tools/use_voice.sh af_heart     # swap, then rebuild
```

The target directory is replaced wholesale, never merged: a leftover clip from
another voice would make a lesson switch voices halfway through.

**One deliberate exception:** every `letter-<X>-phoneme.m4a` in
`VoiceClips/af_heart/` is actually voiced by af_bella, not af_heart --
af_heart's phonics sounds were judged wrong or just less pleasant on a
listen-through, af_bella's were not, for all 26 letters. See
`PHONEME_VOICE_OVERRIDE` in `tools/gen_clips.py`. The letter *names* and
every other af_heart clip are unaffected. The af_heart-voiced phonics this
replaced are kept at `VoiceClips/af_heart-phonics-backup-2026-09-14/` in
case af_bella's are ever rejected later.

## What is recorded

| File | Says |
|---|---|
| `letter-<ID>-name.m4a` | the letter's name — "Bee" |
| `letter-<ID>-phoneme.m4a` | its phonics sound — "buh" |
| `letter-<ID>-word.m4a` | "Bee is for Ball" |
| `number-<ID>-name.m4a` / `-counting.m4a` | "Number one." / "One, two, three." — plus `-counting.json`, see *Counting timings* |
| `trace-prompt-number-<N>.m4a` / `number-thats-<N>.m4a` | Trace Numbers, digits 0–9 — "Trace three." / "That's three." |
| `quiz-*`, `count-*`, `word-*`, `trace-*`, `letter-thats-*`, `praise-*` | every other spoken line — see `Content/SpokenClips.swift` |

`Content/SpokenClips.swift` is the authority on key names; the generators
mirror it. A key with no matching file falls back to synthesis **silently** —
no crash, no warning — which is why the checks below exist.

Teaching sequences fall back per whole sequence (all three beats or none, so a
lesson never switches voice mid-way). Ordinary lines fall back per line,
deliberately: praise containing the child's name can never be a recording, and
holding the whole line to that would keep every correct answer synthesised.

## Generating

The pipeline lives in `tools/`. It needs its own virtualenv, which is not
checked in:

```bash
python3.12 -m venv venv && ./venv/bin/pip install kokoro soundfile openai-whisper
./venv/bin/python tools/gen_clips.py   --voice af_heart --out A   # 98 teaching clips
./venv/bin/python tools/gen_phase_b.py --voice af_heart --out B   # 1425 game/trace/praise clips
```

Copy the output into `VoiceClips/<voice>/` and run `tools/use_voice.sh`.

### Regenerating just a few clips

A full run is ~1 hour. To fix one clip, target it by key fragment:

```bash
# re-roll a clip that came out wrong (generation is not deterministic)
./venv/bin/python tools/gen_clips.py --voice af_heart --out A \
    --only number-5-name --force

# regenerate one game's words after a wording change
./venv/bin/python tools/gen_phase_b.py --voice af_heart --out B \
    --only word-spell-bug --only word-alone-bug --force
```

`--only` takes a substring of the clip key and is repeatable; everything else
in the output directory is left untouched. Without `--force`, existing clips
are skipped — which is what makes an interrupted run resumable.

**When a partial run is not enough.** Praise and greetings are keyed by
*position* (`praise-0` … `praise-9`), so adding or removing one shifts every
clip after it. Regenerating only the changed entry leaves the app saying
"Brilliant!" where it means "Fantastic!". Whenever a position-keyed list
changes length, regenerate that whole family and copy it over.

Environment gotchas, both handled inside the scripts:

- **Python 3.13+ won't work.** Kokoro pulls spaCy → thinc → blis, which has no
  wheels for newer interpreters and fails to compile. Use 3.12.
- **espeak-ng data path.** The `espeakng-loader` dylib has its build machine's
  path baked in, so synthesis aborts with `Error processing file
  .../phontab: No such file or directory` unless `ESPEAK_DATA_PATH` is set.

## Rules the audio depends on

Every one of these was found by listening, after the obvious approach failed.
Changing any of them means regenerating and listening again.

**Never generate slowly.** `SPEED` stays at `1.0`. Asking Kokoro for slow
speech corrupts it: at 0.8 it prepends a schwa, turning "Trace B" into
"a-Trace B" and a lone "Bee" into "a B". Confirmed by transcribing the same
lines generated at 1.0 / 0.9 / 0.8. The slowdown for toddlers happens at
playback instead — `RecordedClipPlayer.playbackRate`, pitch preserved — which
also makes the speed a one-line change rather than an hour of regeneration.

**Letter names are spelled, not spelt out.** Consonant-initial names use plain
spelling ("Bee.", "Double you.") because the phoneme-override form makes the
model prepend a schwa. Vowel-initial names use pinned phonemes
(`[A](/ˈeɪ/)`) because spelling "A" as "Ay" is read as /aɪ/ — "eye".

**Letters inside sentences are bare.** "Can you find B?", not "the letter B" —
a clip of "the letter B" says "the letter Bee", which hears as the insect.
`Spoken.letter` does this; see its comment for the failure mode it used to
guard against.

**Phonics sounds carry a schwa, and which one depends on the sound.**
Sibilants (S, Z, X) take a short schwa — `/sːə/` stretches the hiss into a
second audible "s", heard as "s suh". Everything else takes a long one —
`/fːə/` — which gives a weak consonant enough energy to register. A bare
consonant on its own is near-inaudible. This matches the app's original
`SpeechService.ipaOverrides`.

**Standalone letters are whole utterances, never spliced.** Cutting the letter
out of "A is for Apple" was tried — the letter sounds better in sentence
context — but every cut length sounded artificially clipped, and word-boundary
detection was no help (Whisper reports the letter ending and "is" starting at
the same timestamp). A plain "Bee." is what ships.

**Trim on generation, not afterwards.** Kokoro pads ~0.45s of silence onto the
front of a clip and ~0.55s onto the end, which stacks with the gap between
beats into seconds of dead air. The generators trim inline so a regenerated set
can't quietly lose the fix.

**A voice can mispronounce one specific word.** af_heart appends an /s/ to
"five" when it is the entire utterance — "Five." becomes "fives". Spelling,
punctuation and phoneme pins all failed; what works is giving the word company,
which is why number names are phrased "Number five." rather than "Five."
Multi-word lines were never affected ("Five apples.", "One, two, three, four,
five."), other voices don't do it, and other words ending the same way
("Twelve.") are fine. Expect the same class of fault elsewhere: check a new
voice's short clips before trusting it.

**Generation is not deterministic.** The same text and voice can produce a good
clip one run and a faulty one the next — a bundled "Eight." came back wrong
while a freshly generated one was clean. So a defect found by ear is not
necessarily reproducible, and regenerating a single clip is a legitimate fix.
It also means a clean verification run does not guarantee the next batch is
clean.

## Open question

Number names are phrased "Number five." for all ten, but only *five* needs the
company — it is the one word af_heart mangles alone. The prefix is there so a
child doesn't hear nine numbers announced one way and the fifth another. Worth
revisiting: plain "One.", "Two." … with "Number five." as the single exception
would be less wordy, at the cost of that inconsistency.

## Checking a generated set

```bash
./venv/bin/python tools/check_content_sync.py                                # run this FIRST
./venv/bin/python tools/check_keys.py   ToddlerLearningApp/Resources/Speech   # or the built .app
./venv/bin/python tools/verify_clips.py ToddlerLearningApp/Resources/Speech
```

- **`check_content_sync.py`** — the generators' content lists (words, letters,
  counting objects, praise, greetings, picture words) against the app's Swift
  sources. Run it after touching either side, and before generating anything.

- **`check_keys.py`** — every key the *generators* can produce has a file, no
  file is unreachable, and every counting clip has an up-to-date timing file.
  Fast.

  Note what this cannot catch: it derives its expectations from the same Python
  lists the generators use, so if those lists disagree with the app, both sides
  agree with each other and it reports "0 missing, 0 orphans" while the app
  falls back to the synthesiser. That is not hypothetical — `WORDS` was once
  typed from memory with 19 of 50 wrong, so more than a third of Build the Word
  was synthesised for days while every check stayed green. A person noticed by
  ear. `check_content_sync.py` exists to close exactly that gap.
- **`verify_clips.py`** — transcribes each clip and compares it against the
  intended words, flagging a spurious leading article. This is what catches the
  schwa artifact in bulk. Slow (~15 min for 1,500 clips).

**Neither can judge `letter-<X>-name` or `-phoneme`.** One-syllable clips
transcribe unreliably — "Bee." has come back as "Be", "Zebay" and "I'll be" —
and a relative duration test was tried and removed, because the artifact
affected every clip in the family and so moved the median along with it. Those
52 clips need a person to listen. Every audio fault in this app so far was
found by ear, not by a script.

## Licensing

Kokoro and its weights are Apache-2.0, which permits commercial use of the
generated audio. The pipeline also pulls GPLv3 components (espeak-ng, via
`espeakng-loader`; `num2words` via misaki). Those run **only on the dev Mac** —
the app bundles nothing but `.m4a` audio, and the GPL governs distribution of
the program rather than the output of running it. Do not embed these libraries
in the app itself.
