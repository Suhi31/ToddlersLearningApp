//
//  ParentDashboardViewModel.swift
//  ToddlerLearningApp
//
//  Spec F3. Everything here is computed from on-device SwiftData. No analytics
//  SDK, no network call, nothing leaves the device.
//

import Foundation

@MainActor
@Observable
final class ParentDashboardViewModel {

    let child: ChildProfile
    private let sessionTimer: SessionTimerService

    let limitOptions: [Int] = [0, 15, 30, 45, 60]

    init(child: ChildProfile, sessionTimer: SessionTimerService) {
        self.child = child
        self.sessionTimer = sessionTimer
    }

    // MARK: - Mastery

    var letters: [Letter] { child.unlockedLetters }

    func mastery(for letter: Letter) -> MasteryLevel {
        child.progress(for: letter.id)?.mastery ?? .new
    }

    func accuracy(for letter: Letter) -> Double {
        child.progress(for: letter.id)?.accuracy ?? 0
    }

    var masteredCount: Int { child.masteredCount }

    var learningCount: Int {
        child.progress.count { $0.mastery == .learning }
    }

    /// Computed directly from the currently-unlocked set rather than by
    /// subtracting `masteredCount`/`learningCount` — those two are counted
    /// across *all* progress records regardless of age, so a parent lowering
    /// the child's age after some letters were mastered at a higher age used
    /// to drive this negative.
    var notStartedCount: Int {
        letters.count { mastery(for: $0) == .new }
    }

    /// The letters worth practising together — surfaced so a parent has
    /// something concrete to do offline, which is what the research says
    /// actually moves the needle.
    var lettersNeedingPractice: [Letter] {
        child.progress
            .filter { $0.attempts >= 2 && $0.accuracy < 0.6 }
            .sorted { $0.accuracy < $1.accuracy }
            .prefix(5)
            .compactMap(\.letter)
    }

    // MARK: - Numbers mastery

    var numbers: [NumberItem] { child.unlockedNumbers }

    func mastery(for number: NumberItem) -> MasteryLevel {
        child.numberProgress(for: number.id)?.mastery ?? .new
    }

    var masteredNumberCount: Int { child.masteredNumberCount }

    var learningNumberCount: Int {
        child.numberProgress.count { $0.mastery == .learning }
    }

    /// Numbers-domain twin of `notStartedCount` — same reasoning applies.
    var notStartedNumberCount: Int {
        numbers.count { mastery(for: $0) == .new }
    }

    /// Numbers-domain twin of `lettersNeedingPractice`.
    var numbersNeedingPractice: [NumberItem] {
        child.numberProgress
            .filter { $0.attempts >= 2 && $0.accuracy < 0.6 }
            .sorted { $0.accuracy < $1.accuracy }
            .prefix(5)
            .compactMap(\.number)
    }

    // MARK: - Time

    var minutesToday: Int {
        SessionTimerService.secondsPlayed(by: child, on: .now) / 60
    }

    var weeklyTotals: [(date: Date, seconds: Int)] {
        SessionTimerService.dailyTotals(for: child, days: 7)
    }

    var weeklyMinutes: Int {
        weeklyTotals.reduce(0) { $0 + $1.seconds } / 60
    }

    var dailyLimitMinutes: Int {
        get { child.dailyLimitMinutes }
        set { child.dailyLimitMinutes = newValue }
    }

    func limitLabel(_ minutes: Int) -> String {
        minutes == 0 ? "Off" : "\(minutes)m"
    }

    var sessionCount: Int { child.sessions.count }

    var totalStars: Int { child.starCount }
    var streak: Int { child.currentStreak }
}
