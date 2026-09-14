//
//  TraceContent.swift
//  ToddlerLearningApp
//
//  What the trace screen works through. Trace Letters and Trace Numbers are
//  the same activity — same validator, same canvas, same rounds — over two
//  different sets, so the screen takes a `TraceKind` rather than there being a
//  near-identical copy of it per set.
//

import Foundation

/// One thing a child can trace: a letter or a digit.
struct TraceItem: Identifiable {

    /// The key into the stroke tables (`LetterTracePathContent`,
    /// `NumberTracePathContent`) and into `TraceProgress` — "A", or "3".
    let id: String

    /// What the header shows.
    let glyph: String

    let colorIndex: Int

    /// "the letter A" / "the number 3", for VoiceOver.
    let accessibilityName: String

    /// Spoken when the item appears — "Trace A."
    let prompt: SpokenLine

    /// Spoken after the praise opener once it's traced — "That's A."
    let completion: SpokenLine
}

enum TraceKind: Hashable, CaseIterable {
    case letters
    case numbers

    var title: String {
        switch self {
        case .letters: "Trace Letters"
        case .numbers: "Trace Numbers"
        }
    }

    /// Singular noun for labels — "Next letter", "Hear the number".
    var itemNoun: String {
        switch self {
        case .letters: "letter"
        case .numbers: "number"
        }
    }

    var items: [TraceItem] {
        switch self {
        case .letters: Self.letterItems
        case .numbers: Self.numberItems
        }
    }

    private static let letterItems: [TraceItem] = AlphabetContent.letters.map { letter in
        let name = letter.uppercase
        return TraceItem(
            id: letter.id,
            glyph: name,
            colorIndex: letter.colorIndex,
            accessibilityName: "the letter \(name)",
            prompt: SpokenLine(clip: Clip.tracePrompt(name), text: "Trace \(Spoken.letter(name))"),
            completion: SpokenLine(clip: Clip.letterThats(name), text: "That's \(Spoken.letter(name)).")
        )
    }

    /// 0–9 — digits, not NumberContent's 1–10: ten is two digits, and zero
    /// is a shape worth learning to write even though nobody counts it.
    ///
    /// Each digit takes the colour of its Learn Numbers card, so 3 is the
    /// same colour on both screens. Zero has no card and continues the cycle
    /// backwards from one.
    private static let numberItems: [TraceItem] = (0...9).map { digit in
        TraceItem(
            id: "\(digit)",
            glyph: "\(digit)",
            colorIndex: NumberContent.number(id: digit)?.colorIndex ?? -1,
            accessibilityName: "the number \(digit)",
            prompt: SpokenLine(clip: Clip.traceNumberPrompt(digit), text: "Trace \(digit)"),
            completion: SpokenLine(clip: Clip.numberThats(digit), text: "That's \(digit).")
        )
    }
}
