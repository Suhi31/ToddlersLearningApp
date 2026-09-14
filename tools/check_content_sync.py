#!/usr/bin/env python3
"""Check the generators' content lists against the app's Swift sources.

    python tools/check_content_sync.py

WHY THIS EXISTS
---------------
`check_keys.py` compares the clips on disk against the keys the *generators*
produce. That catches a missing file, but it cannot catch the generators being
wrong about what the app says -- both sides read the same hand-written Python
lists, so they agree with each other while disagreeing with the app.

That is not hypothetical. `WORDS` was once typed from memory and 19 of the 50
words were wrong: `word-spell-bug` and 18 others were never generated, so more
than a third of Build the Word silently fell back to the synthesiser, while
check_keys.py reported "0 missing, 0 orphans" the whole time. A person noticed
by ear.

So this parses the Swift content files and compares them to the Python lists.
Run it after touching either side.
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

REPO = Path(__file__).resolve().parent.parent
CONTENT = REPO / "ToddlerLearningApp" / "Content"


def swift_word_ids():
    source = (CONTENT / "WordBuildContent.swift").read_text()
    return sorted(w.lower() for w in re.findall(r'WordItem\(id:\s*"([A-Z]+)"', source))


def swift_letter_ids():
    source = (CONTENT / "AlphabetContent.swift").read_text()
    return sorted(set(re.findall(r'Letter\(id:\s*"([A-Z])"', source)))


def swift_picture_words():
    """Letter -> [main word, second word] as the app pairs them."""
    source = (CONTENT / "AlphabetContent.swift").read_text()
    main = {letter: word for letter, word in
            re.findall(r'Letter\(id:\s*"([A-Z])",\s*word:\s*"([^"]+)"', source)}
    second_block = re.search(r'secondPictureWords:\s*\[String:\s*String\]\s*=\s*\[(.*?)\]',
                             source, re.S)
    second = dict(re.findall(r'"([A-Z])":\s*"([^"]+)"', second_block.group(1))) if second_block else {}
    return {letter: [main[letter]] + ([second[letter]] if letter in second else [])
            for letter in sorted(main)}


def swift_trace_digits():
    source = (CONTENT / "NumberTracePathContent.swift").read_text()
    return sorted(int(d) for d in re.findall(r'"([0-9])":\s*LetterTracePath', source))


def swift_counting_objects():
    source = (CONTENT / "NumberContent.swift").read_text()
    return sorted(re.findall(r'singular:\s*"([^"]+)",\s*plural:\s*"([^"]+)"', source))


def swift_praise():
    source = (CONTENT / "SpokenPhrases.swift").read_text()
    block = re.search(r'static let exclamations\s*=\s*\[(.*?)\]', source, re.S)
    return re.findall(r'"([^"]+)"', block.group(1)) if block else []


def swift_greetings():
    source = (CONTENT / "SpokenPhrases.swift").read_text()
    block = re.search(r'static let lines\s*=\s*\[(.*?)\]', source, re.S)
    return re.findall(r'"([^"]+)"', block.group(1)) if block else []


def compare(label, from_swift, from_python, ordered=False):
    """Report a difference. Order matters where clips are keyed by index."""
    if ordered:
        ok = list(from_swift) == list(from_python)
        detail = "" if ok else f"\n      swift : {list(from_swift)}\n      python: {list(from_python)}"
    else:
        missing = sorted(set(from_swift) - set(from_python))
        extra = sorted(set(from_python) - set(from_swift))
        ok = not missing and not extra
        detail = ""
        if missing:
            detail += f"\n      in app, not generated: {missing}"
        if extra:
            detail += f"\n      generated, not in app: {extra}"

    mark = "ok  " if ok else "FAIL"
    print(f"  [{mark}] {label} ({len(from_swift)} in app, {len(from_python)} in generator){detail}")
    return ok


def main():
    import gen_phase_b
    import gen_clips

    print("Comparing the app's Swift content against the generators' lists\n")

    results = [
        compare("Build the Word words", swift_word_ids(),
                sorted(w.lower() for w in gen_phase_b.WORDS)),
        compare("letters", swift_letter_ids(),
                sorted(letter for letter, *_ in gen_clips.LETTERS)),
        compare("counting objects", swift_counting_objects(),
                sorted(gen_phase_b.COUNTING_OBJECTS)),
        compare("traceable digits", swift_trace_digits(),
                sorted(gen_phase_b.TRACE_DIGITS)),
        # Indexed by position: a reordering silently remaps every clip.
        compare("praise openers", swift_praise(), gen_phase_b.PRAISE, ordered=True),
        compare("greetings", swift_greetings(), gen_phase_b.GREETINGS, ordered=True),
    ]

    swift_pictures = swift_picture_words()
    results.append(compare("letter picture words",
                           sorted(f"{k}:{w}" for k, ws in swift_pictures.items() for w in ws),
                           sorted(f"{k}:{w}" for k, ws in gen_phase_b.PICTURE_WORDS.items() for w in ws)))

    print()
    if all(results):
        print("Generators are in step with the app.")
        return 0
    print("OUT OF STEP — clips for the missing entries will fall back to the")
    print("synthesiser, and no other check will notice.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
