//
//  NumberContent.swift
//  ToddlerLearningApp
//
//  Static content, mirrors AlphabetContent.swift. Each number pairs with a
//  single emoji shown *repeated* — the pedagogy for numbers is counting a
//  quantity, not associating a word the way a letter pairs with "Apple".
//

import Foundation

struct NumberItem: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let emoji: String
    let colorIndex: Int
}

enum NumberContent {

    static let numbers: [NumberItem] = [
        NumberItem(id: 1, name: "One", emoji: "🍎", colorIndex: 0),
        NumberItem(id: 2, name: "Two", emoji: "🎈", colorIndex: 1),
        NumberItem(id: 3, name: "Three", emoji: "🐱", colorIndex: 2),
        NumberItem(id: 4, name: "Four", emoji: "🐶", colorIndex: 3),
        NumberItem(id: 5, name: "Five", emoji: "🐟", colorIndex: 4),
        NumberItem(id: 6, name: "Six", emoji: "🦋", colorIndex: 5),
        NumberItem(id: 7, name: "Seven", emoji: "🌟", colorIndex: 6),
        NumberItem(id: 8, name: "Eight", emoji: "🍪", colorIndex: 0),
        NumberItem(id: 9, name: "Nine", emoji: "🎁", colorIndex: 1),
        NumberItem(id: 10, name: "Ten", emoji: "🚗", colorIndex: 2)
    ]

    private static let index: [Int: NumberItem] = Dictionary(
        uniqueKeysWithValues: numbers.map { ($0.id, $0) }
    )

    static func number(id: Int) -> NumberItem? {
        index[id]
    }

    /// How much of 1–10 a child is shown, gated by age — same rationale as
    /// `AlphabetContent.unlockedCount(forAge:)`.
    static func unlockedCount(forAge age: Int) -> Int {
        switch age {
        case ..<3: 5
        default: numbers.count
        }
    }

    static func unlockedNumbers(forAge age: Int) -> [NumberItem] {
        Array(numbers.prefix(unlockedCount(forAge: age)))
    }
}
