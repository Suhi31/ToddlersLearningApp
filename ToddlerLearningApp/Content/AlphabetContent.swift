//
//  AlphabetContent.swift
//  ToddlerLearningApp
//
//  The full alphabet as static content. Every word is concrete and picturable —
//  abstractions like "queen" are hard for a two-year-old, so each letter also
//  carries a second, simpler image.
//

import Foundation

enum AlphabetContent {

    static let letters: [Letter] = [
        Letter(id: "A", word: "Apple",     phoneme: "ah",   emojis: ["🍎", "🐜"], colorIndex: 0),
        Letter(id: "B", word: "Ball",      phoneme: "buh",  emojis: ["⚽️", "🎈"], colorIndex: 1),
        Letter(id: "C", word: "Cat",       phoneme: "kuh",  emojis: ["🐱", "🚗"], colorIndex: 2),
        Letter(id: "D", word: "Dog",       phoneme: "duh",  emojis: ["🐶", "🍩"], colorIndex: 3),
        Letter(id: "E", word: "Elephant",  phoneme: "eh",   emojis: ["🐘", "🥚"], colorIndex: 4),
        Letter(id: "F", word: "Fish",      phoneme: "ff",   emojis: ["🐟", "🌸"], colorIndex: 5),
        Letter(id: "G", word: "Goat",      phoneme: "guh",  emojis: ["🐐", "🎁"], colorIndex: 6),
        Letter(id: "H", word: "Hat",       phoneme: "huh",  emojis: ["🎩", "🏠"], colorIndex: 0),
        Letter(id: "I", word: "Ice cream", phoneme: "ih",   emojis: ["🍦", "🧊"], colorIndex: 1),
        Letter(id: "J", word: "Juice",     phoneme: "juh",  emojis: ["🧃", "🐆"], colorIndex: 2),
        Letter(id: "K", word: "Kite",      phoneme: "kuh",  emojis: ["🪁", "🔑"], colorIndex: 3),
        Letter(id: "L", word: "Lion",      phoneme: "ll",   emojis: ["🦁", "🍋"], colorIndex: 4),
        Letter(id: "M", word: "Monkey",    phoneme: "mm",   emojis: ["🐵", "🌙"], colorIndex: 5),
        Letter(id: "N", word: "Nest",      phoneme: "nn",   emojis: ["🪺", "👃"], colorIndex: 6),
        Letter(id: "O", word: "Orange",    phoneme: "oh",   emojis: ["🍊", "🐙"], colorIndex: 0),
        Letter(id: "P", word: "Parrot",    phoneme: "puh",  emojis: ["🦜", "🍕"], colorIndex: 1),
        Letter(id: "Q", word: "Queen",     phoneme: "kwuh", emojis: ["👸", "❓"], colorIndex: 2),
        Letter(id: "R", word: "Rabbit",    phoneme: "rr",   emojis: ["🐰", "🌈"], colorIndex: 3),
        Letter(id: "S", word: "Sun",       phoneme: "sss",  emojis: ["☀️", "🐍"], colorIndex: 4),
        Letter(id: "T", word: "Tiger",     phoneme: "tuh",  emojis: ["🐯", "🚂"], colorIndex: 5),
        Letter(id: "U", word: "Umbrella",  phoneme: "uh",   emojis: ["☂️", "🦄"], colorIndex: 6),
        Letter(id: "V", word: "Van",       phoneme: "vv",   emojis: ["🚐", "🎻"], colorIndex: 0),
        Letter(id: "W", word: "Watch",     phoneme: "wuh",  emojis: ["⌚️", "🐋"], colorIndex: 1),
        Letter(id: "X", word: "X-ray",     phoneme: "ks",   emojis: ["🩻", "❌"], colorIndex: 2),
        Letter(id: "Y", word: "Yo-yo",     phoneme: "yuh",  emojis: ["🪀", "💛"], colorIndex: 3),
        Letter(id: "Z", word: "Zebra",     phoneme: "zz",   emojis: ["🦓", "⚡️"], colorIndex: 4)
    ]

    private static let index: [String: Letter] = Dictionary(
        uniqueKeysWithValues: letters.map { ($0.id, $0) }
    )

    static func letter(id: String) -> Letter? {
        index[id]
    }

    /// How much of the alphabet a child is shown, gated by age (spec F2).
    /// A two-year-old faced with 26 tiles disengages; A–J is a workable set.
    /// From age 3 on, the full alphabet is available.
    static func unlockedCount(forAge age: Int) -> Int {
        switch age {
        case ..<3: 10
        default: letters.count
        }
    }

    static func unlockedLetters(forAge age: Int) -> [Letter] {
        Array(letters.prefix(unlockedCount(forAge: age)))
    }

    // MARK: - Look-alikes

    /// Uppercase letters children commonly mix up by shape. Once a letter is
    /// known, the quiz offers these alongside it, so recognising it means
    /// telling it from its neighbours rather than spotting it among strangers.
    private static let lookAlikePairs: [(String, String)] = [
        ("B", "D"), ("B", "E"), ("B", "P"), ("B", "R"), ("C", "G"), ("C", "O"),
        ("D", "O"), ("E", "F"), ("F", "P"), ("G", "O"), ("G", "Q"), ("H", "N"),
        ("I", "J"), ("I", "L"), ("I", "T"), ("J", "U"), ("K", "R"), ("K", "X"),
        ("L", "T"), ("M", "N"), ("M", "W"), ("N", "Z"), ("O", "Q"), ("P", "R"),
        ("S", "Z"), ("U", "V"), ("V", "W"), ("V", "Y"), ("X", "Y")
    ]

    private static let lookAlikeIndex: [String: Set<String>] =
        lookAlikePairs.reduce(into: [:]) { index, pair in
            index[pair.0, default: []].insert(pair.1)
            index[pair.1, default: []].insert(pair.0)
        }

    static func lookAlikes(of letterID: String) -> Set<String> {
        lookAlikeIndex[letterID] ?? []
    }

    // MARK: - Pictures

    /// A word for each letter's second emoji, where it has a clear one — see
    /// `Letter.pictures`. J, Q, X and Z are left out: their second emoji (a
    /// leopard, ❓, ❌, ⚡️) has no plain word starting with the letter.
    fileprivate static let secondPictureWords: [String: String] = [
        "A": "Ant", "B": "Balloon", "C": "Car", "D": "Donut", "E": "Egg",
        "F": "Flower", "G": "Gift", "H": "House", "I": "Ice", "K": "Key",
        "L": "Lemon", "M": "Moon", "N": "Nose", "O": "Octopus", "P": "Pizza",
        "R": "Rainbow", "S": "Snake", "T": "Train", "U": "Unicorn", "V": "Violin",
        "W": "Whale", "Y": "Yellow"
    ]
}

extension Letter {

    /// The letter's own picture and word.
    var mainPicture: LetterPicture {
        LetterPicture(emoji: emojis.first ?? "❓", word: word)
    }

    /// Every picture the letter can be shown with, each paired with its word.
    var pictures: [LetterPicture] {
        guard emojis.count > 1, let secondWord = AlphabetContent.secondPictureWords[id] else {
            return [mainPicture]
        }
        return [mainPicture, LetterPicture(emoji: emojis[1], word: secondWord)]
    }
}
