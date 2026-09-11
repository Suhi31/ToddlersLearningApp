//
//  WordBuildContent.swift
//  ToddlerLearningApp
//
//  A curated set of short, picturable words for the word-building game.
//  AlphabetContent's words ("Elephant", "Umbrella") are the right length for
//  a single letter-sound association but far too long to hand-spell at this
//  age — this is deliberately its own short, no-repeated-letter word list.
//
//  Three-letter words for the first levels, four-letter ones for the last —
//  see `WordBuildProgression`. Every word has a clear, single-meaning emoji
//  and reads unambiguously aloud (no BOW, which could be "bough").
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
        // Three letters
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
        WordItem(id: "LOG", emoji: "🪵", colorIndex: 6),
        WordItem(id: "FOX", emoji: "🦊", colorIndex: 0),
        WordItem(id: "BUG", emoji: "🐛", colorIndex: 1),
        WordItem(id: "OWL", emoji: "🦉", colorIndex: 2),
        WordItem(id: "MAP", emoji: "🗺️", colorIndex: 3),
        WordItem(id: "ANT", emoji: "🐜", colorIndex: 4),
        WordItem(id: "BAT", emoji: "🦇", colorIndex: 5),
        WordItem(id: "COW", emoji: "🐄", colorIndex: 6),
        WordItem(id: "CAR", emoji: "🚗", colorIndex: 0),
        WordItem(id: "KEY", emoji: "🔑", colorIndex: 1),
        WordItem(id: "PEN", emoji: "🖊️", colorIndex: 2),
        WordItem(id: "SAW", emoji: "🪚", colorIndex: 3),
        WordItem(id: "WEB", emoji: "🕸️", colorIndex: 4),
        WordItem(id: "NUT", emoji: "🥜", colorIndex: 5),
        WordItem(id: "PIE", emoji: "🥧", colorIndex: 6),
        WordItem(id: "ICE", emoji: "🧊", colorIndex: 0),
        WordItem(id: "EAR", emoji: "👂", colorIndex: 1),
        WordItem(id: "TIE", emoji: "👔", colorIndex: 2),
        WordItem(id: "LEG", emoji: "🦵", colorIndex: 3),
        WordItem(id: "RAM", emoji: "🐏", colorIndex: 4),
        WordItem(id: "JAR", emoji: "🫙", colorIndex: 5),

        // Four letters
        WordItem(id: "FROG", emoji: "🐸", colorIndex: 6),
        WordItem(id: "FISH", emoji: "🐟", colorIndex: 0),
        WordItem(id: "DUCK", emoji: "🦆", colorIndex: 1),
        WordItem(id: "BEAR", emoji: "🐻", colorIndex: 2),
        WordItem(id: "LION", emoji: "🦁", colorIndex: 3),
        WordItem(id: "CAKE", emoji: "🎂", colorIndex: 4),
        WordItem(id: "BOAT", emoji: "⛵", colorIndex: 5),
        WordItem(id: "STAR", emoji: "⭐", colorIndex: 6),
        WordItem(id: "BIRD", emoji: "🐦", colorIndex: 0),
        WordItem(id: "CRAB", emoji: "🦀", colorIndex: 1),
        WordItem(id: "SOCK", emoji: "🧦", colorIndex: 2),
        WordItem(id: "DRUM", emoji: "🥁", colorIndex: 3),
        WordItem(id: "KITE", emoji: "🪁", colorIndex: 4),
        WordItem(id: "CORN", emoji: "🌽", colorIndex: 5),
        WordItem(id: "MILK", emoji: "🥛", colorIndex: 6),
        WordItem(id: "GIFT", emoji: "🎁", colorIndex: 0)
    ]
}
