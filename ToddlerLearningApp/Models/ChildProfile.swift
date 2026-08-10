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

    var masteredCount: Int {
        progress.count { $0.mastery == .mastered }
    }

    /// 0...1 across the letters this child has actually been shown.
    var overallProgress: Double {
        let total = unlockedLetters.count
        guard total > 0 else { return 0 }
        return Double(masteredCount) / Double(total)
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

    var masteredNumberCount: Int {
        numberProgress.count { $0.mastery == .mastered }
    }

    func numberProgress(for numberID: Int) -> NumberProgress? {
        numberProgress.first { $0.numberID == numberID }
    }
}
