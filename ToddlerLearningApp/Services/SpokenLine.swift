//
//  SpokenLine.swift
//  ToddlerLearningApp
//
//  One line of speech, plus the identity of the recording that says it.
//
//  `SpeechService` only ever needs `text`. `RecordedSpeechService` needs to
//  know *which* recording a line corresponds to, and free-form text is no use
//  for that — "Can you find the letter A?" can't be looked up by its own
//  characters without baking punctuation and phrasing into filenames. So a
//  line carries a short stable `clip` key alongside the words.
//
//  A `nil` key means "synthesise this, always". That is not a gap to be filled
//  in later: it is the right answer for anything containing the child's name,
//  which is typed by a parent and can never be a bundled recording.
//

import Foundation

struct SpokenLine: Sendable, Equatable {

    /// Filename stem of the recording, without extension — e.g.
    /// "quiz-letter-find-2-A". `nil` for lines that must be synthesised.
    let clip: String?

    /// The words, for synthesis and for anything reading the line as text.
    let text: String

    init(clip: String?, text: String) {
        self.clip = clip
        self.text = text
    }

    /// A line with no recording: synthesised every time.
    static func spoken(_ text: String) -> SpokenLine {
        SpokenLine(clip: nil, text: text)
    }
}

extension SpokenLine: ExpressibleByStringLiteral {

    /// So a line that has no recording yet can still be written as a plain
    /// string at the call site. Deliberately keyless — a clip key is something
    /// an author opts into, never something inferred from the words.
    init(stringLiteral value: String) {
        self.init(clip: nil, text: value)
    }
}
