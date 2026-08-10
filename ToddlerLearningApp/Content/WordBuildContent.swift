//
//  WordBuildContent.swift
//  ToddlerLearningApp
//
//  A curated set of short, picturable words for the word-building game.
//  AlphabetContent's words ("Elephant", "Umbrella") are the right length for
//  a single letter-sound association but far too long to hand-spell at this
//  age — this is deliberately its own short, no-repeated-letter word list.
//

import Foundation

struct WordItem: Identifiable, Hashable, Sendable {
    let id: String
    let emoji: String
    let colorIndex: Int

    var letters: [String] {
        id.map { String($0) }
    }
}

enum WordBuildContent {

    static let words: [WordItem] = [
        WordItem(id: "CAT", emoji: "🐱", colorIndex: 0),
        WordItem(id: "DOG", emoji: "🐶", colorIndex: 1),
        WordItem(id: "SUN", emoji: "☀️", colorIndex: 2),
        WordItem(id: "HAT", emoji: "🎩", colorIndex: 3),
        WordItem(id: "CUP", emoji: "🥤", colorIndex: 4),
        WordItem(id: "PIG", emoji: "🐷", colorIndex: 5),
        WordItem(id: "BUS", emoji: "🚌", colorIndex: 6),
        WordItem(id: "BED", emoji: "🛏️", colorIndex: 0),
        WordItem(id: "BOX", emoji: "📦", colorIndex: 1),
        WordItem(id: "VAN", emoji: "🚐", colorIndex: 2),
        WordItem(id: "FAN", emoji: "🪭", colorIndex: 3),
        WordItem(id: "NET", emoji: "🥅", colorIndex: 4),
        WordItem(id: "HEN", emoji: "🐔", colorIndex: 5),
        WordItem(id: "LOG", emoji: "🪵", colorIndex: 6)
    ]
}
