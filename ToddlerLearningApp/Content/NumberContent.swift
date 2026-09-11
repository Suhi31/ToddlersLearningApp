//
//  NumberContent.swift
//  ToddlerLearningApp
//
//  Static content, mirrors AlphabetContent.swift. Each number pairs with a
//  single emoji, shown *repeated* on Learn Numbers — the pedagogy for numbers
//  is counting a quantity, not associating a word the way a letter pairs with
//  "Apple".
//
//  Count & Find deliberately doesn't use that pairing: if 🎈 only ever came in
//  twos, a child soon answers "two" on sight of a balloon without counting
//  anything. The quiz draws from `countingObjects` instead, chosen
//  independently of the count — see `CountingObjectDeck`.
//

import Foundation

struct NumberItem: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let emoji: String
    let colorIndex: Int
}

/// Something to count in Count & Find. Tied to no particular number — any
/// object can be shown any number of times.
struct CountingObject: Hashable, Sendable {
    let emoji: String
    let singular: String
    let plural: String

    func name(forCount count: Int) -> String {
        count == 1 ? singular : plural
    }
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

    /// Everyday things a toddler recognises on sight, visually distinct from
    /// one another, and each a single thing — nothing that already comes as a
    /// pair or a bunch (👟, 🍇), which would make "how many?" ambiguous.
    static let countingObjects: [CountingObject] = [
        CountingObject(emoji: "🍎", singular: "apple", plural: "apples"),
        CountingObject(emoji: "🍌", singular: "banana", plural: "bananas"),
        CountingObject(emoji: "🍓", singular: "strawberry", plural: "strawberries"),
        CountingObject(emoji: "🍊", singular: "orange", plural: "oranges"),
        CountingObject(emoji: "🥕", singular: "carrot", plural: "carrots"),
        CountingObject(emoji: "🍪", singular: "cookie", plural: "cookies"),
        CountingObject(emoji: "🧁", singular: "cupcake", plural: "cupcakes"),
        CountingObject(emoji: "🍩", singular: "donut", plural: "donuts"),
        CountingObject(emoji: "🐶", singular: "dog", plural: "dogs"),
        CountingObject(emoji: "🐱", singular: "cat", plural: "cats"),
        CountingObject(emoji: "🐟", singular: "fish", plural: "fish"),
        CountingObject(emoji: "🦋", singular: "butterfly", plural: "butterflies"),
        CountingObject(emoji: "🐸", singular: "frog", plural: "frogs"),
        CountingObject(emoji: "🐥", singular: "chick", plural: "chicks"),
        CountingObject(emoji: "🐞", singular: "ladybug", plural: "ladybugs"),
        CountingObject(emoji: "🐢", singular: "turtle", plural: "turtles"),
        CountingObject(emoji: "🦆", singular: "duck", plural: "ducks"),
        CountingObject(emoji: "🐝", singular: "bee", plural: "bees"),
        CountingObject(emoji: "🐰", singular: "bunny", plural: "bunnies"),
        CountingObject(emoji: "🐘", singular: "elephant", plural: "elephants"),
        CountingObject(emoji: "🎈", singular: "balloon", plural: "balloons"),
        CountingObject(emoji: "⭐", singular: "star", plural: "stars"),
        CountingObject(emoji: "🚗", singular: "car", plural: "cars"),
        CountingObject(emoji: "🚌", singular: "bus", plural: "buses"),
        CountingObject(emoji: "⛵", singular: "boat", plural: "boats"),
        CountingObject(emoji: "🚀", singular: "rocket", plural: "rockets"),
        CountingObject(emoji: "⚽", singular: "ball", plural: "balls"),
        CountingObject(emoji: "🎁", singular: "present", plural: "presents"),
        CountingObject(emoji: "🧸", singular: "teddy bear", plural: "teddy bears"),
        CountingObject(emoji: "🌸", singular: "flower", plural: "flowers"),
        CountingObject(emoji: "🌳", singular: "tree", plural: "trees")
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

/// Deals counting objects from a shuffled deck rather than calling
/// `randomElement()` each time: every object comes up once before any comes
/// up again, so a round shows a real spread of things instead of whatever
/// the dice favour — and never the same object twice in a row, even across
/// a reshuffle.
final class CountingObjectDeck {

    private let objects: [CountingObject]
    private var remaining: [CountingObject] = []
    private var lastDealt: CountingObject?

    init(objects: [CountingObject] = NumberContent.countingObjects) {
        precondition(!objects.isEmpty, "A counting deck needs at least one object")
        self.objects = objects
    }

    func next() -> CountingObject {
        if remaining.isEmpty {
            remaining = objects.shuffled()
            // Dealt from the end, so that's where a repeat of the previous
            // deck's final object would bite.
            if remaining.count > 1, remaining.last == lastDealt {
                remaining.swapAt(0, remaining.count - 1)
            }
        }
        let object = remaining.removeLast()
        lastDealt = object
        return object
    }
}
