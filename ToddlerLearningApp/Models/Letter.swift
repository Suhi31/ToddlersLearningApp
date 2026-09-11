//
//  Letter.swift
//  ToddlerLearningApp
//
//  Static content, not user data — a plain value type. Deliberately free of
//  SwiftUI so the model layer carries no UI dependency; `colorIndex` is
//  resolved to a real colour by the view via `AppColors.paletteColor(_:)`.
//

import Foundation

struct Letter: Identifiable, Hashable, Sendable {

    /// The uppercase character, which doubles as the stable identifier used by
    /// `LetterProgress.letterID`.
    let id: String

    let word: String

    /// A rough spelling of the letter's *sound* rather than its name, e.g. "buh"
    /// for B. Teaching the sound is what actually transfers to reading.
    let phoneme: String

    let emojis: [String]

    let colorIndex: Int

    var uppercase: String { id }
}

/// One picture a letter can be shown with, and the word it stands for — so
/// "A is for …" always names what is actually on screen.
struct LetterPicture: Hashable, Sendable {
    let emoji: String
    let word: String
}
