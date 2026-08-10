//
//  LetterProgress.swift
//  ToddlerLearningApp
//
//  One row per (child, letter). Drives both the parent dashboard's mastery grid
//  and the adaptive selection in `ProgressService`.
//

import Foundation
import SwiftData

@Model
final class LetterProgress {

    var id: UUID = UUID()

    /// Matches `Letter.id`, e.g. "A".
    var letterID: String = ""

    var attempts: Int = 0
    var correctCount: Int = 0
    var consecutiveCorrect: Int = 0
    var consecutiveMisses: Int = 0
    var lastSeenAt: Date?

    /// `MasteryLevel` is stored as its raw value; SwiftData handles primitives
    /// more predictably than enums across schema migrations.
    var masteryRaw: Int = MasteryLevel.new.rawValue

    var child: ChildProfile?

    init(letterID: String) {
        self.id = UUID()
        self.letterID = letterID
    }

    var mastery: MasteryLevel {
        get { MasteryLevel(rawValue: masteryRaw) ?? .new }
        set { masteryRaw = newValue.rawValue }
    }

    var letter: Letter? {
        AlphabetContent.letter(id: letterID)
    }

    var accuracy: Double {
        guard attempts > 0 else { return 0 }
        return Double(correctCount) / Double(attempts)
    }
}
