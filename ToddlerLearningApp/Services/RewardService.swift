//
//  RewardService.swift
//  ToddlerLearningApp
//
//  Spec F4. Stars, trophies and streaks — the retention loop.
//
//  Deliberately non-punitive: a broken streak resets quietly and is never
//  surfaced as a loss. Loss-aversion mechanics that work on adult language
//  learners are not appropriate for a three-year-old.
//

import Foundation
import SwiftData

struct Trophy: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
    let detail: String
    let isUnlocked: Bool
}

@MainActor
final class RewardService {

    /// Spec F4's "gentle daily goal" — a fixed star target shown on Home,
    /// reset silently each day via `ChildProfile.starsEarnedTodayCount`.
    static let dailyGoalTarget = 5

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Stars

    func awardStars(_ count: Int = 1, to child: ChildProfile) {
        child.starCount += count
        recordDailyGoalProgress(count, for: child)
        save()
    }

    private func recordDailyGoalProgress(_ count: Int, for child: ChildProfile) {
        if let date = child.starsEarnedTodayDate, Calendar.current.isDateInToday(date) {
            child.starsEarnedToday += count
        } else {
            child.starsEarnedToday = count
            child.starsEarnedTodayDate = .now
        }
    }

    // MARK: - Streak

    /// Call once per session start. Advances the streak on consecutive calendar
    /// days, resets silently after a gap.
    func registerPlay(for child: ChildProfile, now: Date = .now) {
        let calendar = Calendar.current

        guard let last = child.lastPlayedDate else {
            child.currentStreak = 1
            child.lastPlayedDate = now
            save()
            return
        }

        if calendar.isDate(last, inSameDayAs: now) {
            return  // already counted today
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(last, inSameDayAs: yesterday) {
            child.currentStreak += 1
        } else {
            child.currentStreak = 1
        }

        child.lastPlayedDate = now
        save()
    }

    // MARK: - Trophies

    /// Trophies are derived from progress rather than stored, so they can never
    /// drift out of sync with the underlying counts.
    func trophies(for child: ChildProfile) -> [Trophy] {
        let mastered = child.masteredCount
        let stars = child.starCount
        let streak = child.currentStreak
        let total = child.unlockedLetters.count

        return [
            Trophy(id: "first-star", title: "First Star", emoji: "⭐️",
                   detail: "Earn your first star",
                   isUnlocked: stars >= 1),
            Trophy(id: "ten-stars", title: "Star Collector", emoji: "🌟",
                   detail: "Earn 10 stars",
                   isUnlocked: stars >= 10),
            Trophy(id: "fifty-stars", title: "Star Master", emoji: "✨",
                   detail: "Earn 50 stars",
                   isUnlocked: stars >= 50),
            Trophy(id: "five-letters", title: "Getting Started", emoji: "🥉",
                   detail: "Master 5 letters",
                   isUnlocked: mastered >= 5),
            Trophy(id: "ten-letters", title: "Halfway Hero", emoji: "🥈",
                   detail: "Master 10 letters",
                   isUnlocked: mastered >= 10),
            Trophy(id: "all-letters", title: "Alphabet Champion", emoji: "🏆",
                   detail: "Master every letter",
                   isUnlocked: total > 0 && mastered >= total),
            Trophy(id: "five-numbers", title: "Counting Starter", emoji: "🔢",
                   detail: "Master 5 numbers",
                   isUnlocked: child.masteredNumberCount >= 5),
            Trophy(id: "all-numbers", title: "Number Whiz", emoji: "🧮",
                   detail: "Master every number",
                   isUnlocked: !child.unlockedNumbers.isEmpty
                       && child.masteredNumberCount >= child.unlockedNumbers.count),
            Trophy(id: "streak-3", title: "Three in a Row", emoji: "🔥",
                   detail: "Play 3 days in a row",
                   isUnlocked: streak >= 3),
            Trophy(id: "streak-7", title: "Week Wonder", emoji: "🎉",
                   detail: "Play 7 days in a row",
                   isUnlocked: streak >= 7)
        ]
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("RewardService save failed: \(error)")
        }
    }
}
