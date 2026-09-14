//
//  SpokenClips.swift
//  ToddlerLearningApp
//
//  The clip keys for every recorded line, in one place.
//
//  These strings are filenames: each one must match a `.m4a` in the bundle
//  (see docs/VOICE_CLIPS.md) or the line falls back to synthesis. Keeping them
//  here rather than inline at the call sites means the generator script and the
//  app describe the same set of recordings in the same vocabulary, and a typo
//  shows up as one robotic line rather than as a build error nobody notices.
//
//  Keys are indexes, not sentences: the phrasing can be reworded freely, but
//  changing a key means regenerating a clip.
//

import Foundation

enum Clip {

    // MARK: - Find the Letter

    /// "Can you find the letter A?" — `variant` selects the phrasing.
    static func quizPrompt(_ letterID: String, variant: Int) -> String {
        "quiz-prompt-\(variant)-\(letterID)"
    }

    /// "That's the letter T!" — the letter the child actually tapped.
    static func quizTapped(_ letterID: String, variant: Int) -> String {
        "quiz-tapped-\(variant)-\(letterID)"
    }

    /// "Can you find the letter A?" as the second half of a miss line, which
    /// is phrased differently from the opening prompt.
    static func quizRetry(_ letterID: String, variant: Int) -> String {
        "quiz-retry-\(variant)-\(letterID)"
    }

    /// "A is for Apple." — keyed by picture word, since a letter has more than
    /// one (Apple and Ant both belong to A).
    static func quizIsFor(_ letterID: String, word: String) -> String {
        "quiz-isfor-\(letterID)-\(slug(word))"
    }

    /// "A is for Apple!" — the exclaimed variant, a different recording.
    static func quizIsForExclaimed(_ letterID: String, word: String) -> String {
        "quiz-isforx-\(letterID)-\(slug(word))"
    }

    /// "A is for Apple. Here it is!" — the second-miss reveal.
    static func quizHereItIs(_ letterID: String, word: String) -> String {
        "quiz-hereitis-\(letterID)-\(slug(word))"
    }

    // MARK: - Count & Find

    /// "How many dogs do you see?"
    static func countPrompt(_ objectPlural: String) -> String {
        "count-prompt-\(slug(objectPlural))"
    }

    /// "Four dogs!" — the body of a correct answer, after the praise opener.
    static func countAnswer(_ count: Int, things: String) -> String {
        "count-answer-\(count)-\(slug(things))"
    }

    /// "There are four dogs. Let's try again."
    static func countRetry(_ count: Int, things: String) -> String {
        "count-retry-\(count)-\(slug(things))"
    }

    // MARK: - Build the Word

    /// "Let's spell Cat!"
    static func wordSpell(_ wordID: String) -> String {
        "word-spell-\(slug(wordID))"
    }

    /// "Cat!" — the word alone, for a replay or on completion.
    static func wordAlone(_ wordID: String) -> String {
        "word-alone-\(slug(wordID))"
    }

    /// "What does Cat start with?"
    static func wordStartsWith(_ wordID: String) -> String {
        "word-starts-\(slug(wordID))"
    }

    /// "What's the last letter?" and "What comes next?" — fixed, wordless.
    static let wordLastLetter = "word-last-letter"
    static let wordNext = "word-next"
    static let wordYouDidIt = "word-you-did-it"

    /// "That's the letter X." / "We need the letter Y!" / "Here's the letter Y!"
    static func letterThats(_ letterID: String) -> String { "letter-thats-\(letterID)" }
    static func letterWeNeed(_ letterID: String) -> String { "letter-weneed-\(letterID)" }
    static func letterHeres(_ letterID: String) -> String { "letter-heres-\(letterID)" }

    /// A letter named on its own, as each tile is placed.
    static func letterName(_ letterID: String) -> String { "letter-\(letterID)-name" }

    // MARK: - Trace

    /// "Trace A."
    static func tracePrompt(_ letterID: String) -> String { "trace-prompt-\(letterID)" }

    /// "Trace three." — Trace Numbers, 0–9.
    static func traceNumberPrompt(_ digit: Int) -> String { "trace-prompt-number-\(digit)" }

    /// "That's three." — the numbers twin of `letterThats`, after the praise
    /// opener when a digit has been traced.
    static func numberThats(_ digit: Int) -> String { "number-thats-\(digit)" }

    // No `traceDone`: finishing a letter now plays a praise opener followed by
    // `letterThats`, which already says "That's A." A separate recording would
    // be the same words twice under two names.

    // MARK: - Praise

    /// Praise, and the mascot's greeting on Home. Both are name-free so they
    /// can be recordings: a line carrying the child's name would have to be
    /// synthesized, and would then play in a different voice from the clip
    /// beside it.
    static func praise(_ index: Int) -> String { "praise-\(index)" }
    static func retryPraise(_ index: Int) -> String { "praise-retry-\(index)" }
    static func greeting(_ index: Int) -> String { "greeting-\(index)" }

    /// Lower-cased, punctuation stripped, spaces hyphenated — "Ice cream"
    /// and "X-ray" have to survive as filenames.
    static func slug(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "-")
    }
}
