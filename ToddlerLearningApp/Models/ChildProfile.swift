//
//  ChildProfile.swift
//  ToddlerLearningApp
//
//  Spec F1. Persisted with SwiftData so a profile survives relaunch, and modelled
//  as a first-class entity so siblings each keep independent progress.
//
//  Privacy: the first name is stored on-device only and is never transmitted.
//  Nothing here is a COPPA "personal identifier" as amended in April 2026.
//

import Foundation
import SwiftData

@Model
final class ChildProfile {

    var id: UUID = UUID()
    var name: String = ""
    var age: Int = 3
    var avatarEmoji: String = "🐰"
    var createdAt: Date = Date()

    /// Parent-set daily allowance in minutes. `0` means no limit (spec F5).
    /// Defaulted off during development so testing isn't cut short — still
    /// toggleable per-child from the Parent Dashboard.
    var dailyLimitMinutes: Int = 0

    var starCount: Int = 0
    var currentStreak: Int = 0
    var lastPlayedDate: Date?

    /// Backing store for today's daily-goal progress (spec F4) — written by
    /// `RewardService.awardStars(_:to:)`. Read through `starsEarnedTodayCount`
    /// rather than directly, since that's what re-checks the date is still
    /// today instead of depending on a reset ever actually running.
    var starsEarnedToday: Int = 0
    var starsEarnedTodayDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \LetterProgress.child)
    var progress: [LetterProgress] = []

    @Relationship(deleteRule: .cascade, inverse: \NumberProgress.child)
    var numberProgress: [NumberProgress] = []

    @Relationship(deleteRule: .cascade, inverse: \TraceProgress.child)
    var traceProgress: [TraceProgress] = []

    @Relationship(deleteRule: .cascade, inverse: \SessionRecord.child)
    var sessions: [SessionRecord] = []

    init(name: String, age: Int, avatarEmoji: String) {
        self.id = UUID()
        self.name = name
        self.age = age
        self.avatarEmoji = avatarEmoji
        self.createdAt = Date()
    }

    // MARK: - Derived

    var unlockedLetters: [Letter] {
        AlphabetContent.unlockedLetters(forAge: age)
    }

    /// Every mastered letter on record, regardless of the child's current age
    /// gate. This is the figure milestone trophies are graded against, so that
    /// changing a child's age can never un-earn one — see `RewardService`.
    var masteredCount: Int {
        progress.count { $0.mastery == .mastered }
    }

    /// Mastered letters *within the set this child is currently shown*.
    ///
    /// Distinct from `masteredCount` because `unlockedLetters` is age-gated to
    /// 10 under age 3 while stored progress is not. Dividing the ungated count
    /// by the gated total is what made Home read "26 of 10 letters mastered"
    /// with a bar past 100% after a parent lowered a child's age.
    var masteredUnlockedCount: Int {
        let unlocked = Set(unlockedLetters.map(\.id))
        return progress.count { $0.mastery == .mastered && unlocked.contains($0.letterID) }
    }

    func progress(for letterID: String) -> LetterProgress? {
        progress.first { $0.letterID == letterID }
    }

    /// Self-corrects for staleness: a count from a prior day is never
    /// returned regardless of when `starsEarnedToday` was last written to,
    /// so no separate "reset at midnight" job is needed.
    var starsEarnedTodayCount: Int {
        guard let starsEarnedTodayDate, Calendar.current.isDateInToday(starsEarnedTodayDate) else { return 0 }
        return starsEarnedToday
    }

    // MARK: - Numbers

    var unlockedNumbers: [NumberItem] {
        NumberContent.unlockedNumbers(forAge: age)
    }

    /// Numbers-domain twin of `masteredCount` — ungated, for trophies.
    var masteredNumberCount: Int {
        numberProgress.count { $0.mastery == .mastered }
    }

    /// Numbers-domain twin of `masteredUnlockedCount`.
    var masteredUnlockedNumberCount: Int {
        let unlocked = Set(unlockedNumbers.map(\.id))
        return numberProgress.count { $0.mastery == .mastered && unlocked.contains($0.numberID) }
    }

    func numberProgress(for numberID: Int) -> NumberProgress? {
        numberProgress.first { $0.numberID == numberID }
    }

    // MARK: - Tracing

    /// Tracing-domain twin of `masteredCount` — ungated, for trophies.
    var masteredTraceCount: Int {
        traceProgress.count { $0.mastery == .mastered }
    }

    /// Tracing-domain twin of `masteredUnlockedCount`.
    var masteredUnlockedTraceCount: Int {
        let unlocked = Set(unlockedLetters.map(\.id))
        return traceProgress.count { $0.mastery == .mastered && unlocked.contains($0.letterID) }
    }

    func traceProgress(for letterID: String) -> TraceProgress? {
        traceProgress.first { $0.letterID == letterID }
    }
}
