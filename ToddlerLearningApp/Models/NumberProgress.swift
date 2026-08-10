//
//  NumberProgress.swift
//  ToddlerLearningApp
//
//  One row per (child, number) — the numbers-domain twin of LetterProgress.
//  Kept as a separate model rather than folding numbers into LetterProgress:
//  the two domains only share the mastery *state machine*, which already
//  lives entirely in MasteryLevel, so there's no real logic to deduplicate by
//  merging the models — only a small amount of CRUD boilerplate, which is
//  cheaper to repeat than to risk a schema rename on an already-shipped model.
//

import Foundation
import SwiftData

@Model
final class NumberProgress {

    var id: UUID = UUID()

    /// Matches `NumberItem.id`, e.g. 3.
    var numberID: Int = 0

    var attempts: Int = 0
    var correctCount: Int = 0
    var consecutiveCorrect: Int = 0
    var consecutiveMisses: Int = 0
    var lastSeenAt: Date?

    var masteryRaw: Int = MasteryLevel.new.rawValue

    var child: ChildProfile?

    init(numberID: Int) {
        self.id = UUID()
        self.numberID = numberID
    }

    var mastery: MasteryLevel {
        get { MasteryLevel(rawValue: masteryRaw) ?? .new }
        set { masteryRaw = newValue.rawValue }
    }

    var number: NumberItem? {
        NumberContent.number(id: numberID)
    }

    var accuracy: Double {
        guard attempts > 0 else { return 0 }
        return Double(correctCount) / Double(attempts)
    }
}
