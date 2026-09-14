//
//  TraceProgress.swift
//  ToddlerLearningApp
//
//  One row per (child, letter) — the tracing-domain twin of LetterProgress.
//  Kept as a separate model rather than folding into LetterProgress: tracing
//  is a distinct skill (motor formation, not letter *recognition*), so a
//  child's trace mastery and quiz mastery are deliberately independent
//  figures, same reasoning NumberProgress's header comment gives for keeping
//  numbers separate from letters.
//

import Foundation
import SwiftData

@Model
final class TraceProgress {

    var id: UUID = UUID()

    /// Matches `TraceItem.id`: a letter ("A") from Trace Letters, or a digit
    /// ("3") from Trace Numbers. Named before numbers could be traced, and
    /// left that way — renaming a stored property needs a schema migration.
    var letterID: String = ""

    var attempts: Int = 0
    var correctCount: Int = 0
    var consecutiveCorrect: Int = 0
    var consecutiveMisses: Int = 0
    var lastSeenAt: Date?

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

    /// `nil` for a traced digit.
    var letter: Letter? {
        AlphabetContent.letter(id: letterID)
    }

    var accuracy: Double {
        guard attempts > 0 else { return 0 }
        return Double(correctCount) / Double(attempts)
    }
}
