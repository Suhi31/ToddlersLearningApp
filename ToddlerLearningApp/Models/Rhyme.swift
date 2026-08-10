//
//  Rhyme.swift
//  ToddlerLearningApp
//
//  Static content, not user data — a plain value type, same convention as
//  Letter/NumberItem. `linkage` is what lets Learn Letters/Learn Numbers
//  surface "hear a rhyme about this" for the letter or number it's tied to.
//

import Foundation

enum RhymeLinkage: Hashable, Sendable {
    case letter(String)   // ties to Letter.id, e.g. "B" for Baa Baa Black Sheep
    case number(Int)      // ties to NumberItem.id, e.g. 5 for Five Little Ducks
    case general          // no specific tie-in
}

struct Rhyme: Identifiable, Hashable, Sendable {

    let id: String

    let title: String

    /// Lyrics, one entry per displayed/highlighted line.
    let lines: [String]

    /// Bundled resource filename, e.g. "twinkle-twinkle.m4a" — see
    /// Resources/RhymeAudio and RhymeAudioService.
    let audioFileName: String

    let emoji: String

    let colorIndex: Int

    let linkage: RhymeLinkage
}
