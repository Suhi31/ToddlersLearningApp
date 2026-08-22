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

    /// One domain's mastery picture, built once and rendered by a single
    /// generic section. The letters and numbers halves of this dashboard were
    /// four near-identical view blocks over eight near-identical accessors.
    struct DomainSummary: Identifiable {

        let id: String

        /// Section heading, e.g. "Letter mastery".
        let title: String

        /// Heading for the practice card, and its parent-facing advice.
        let practiceTitle: String
        let practiceAdvice: String

        /// The grid cells, in display order.
        let cells: [Cell]

        let masteredCount: Int
        let learningCount: Int
        let notStartedCount: Int

        /// The items worth practising together, already ranked worst-first.
        let needsPractice: [String]

        struct Cell: Identifiable {
            let id: String
            let label: String
            let mastery: MasteryLevel
        }
    }

    var letterSummary: DomainSummary {
        let letters = child.unlockedLetters
        let mastery = { (letter: Letter) in self.child.progress(for: letter.id)?.mastery ?? .new }

        return DomainSummary(
            id: "letters",
            title: "Letter mastery",
            practiceTitle: "Worth practising together",
            practiceAdvice: "These come up wrong most often. Pointing them out in books or on signs helps more than extra screen time.",
            cells: letters.map { .init(id: $0.id, label: $0.uppercase, mastery: mastery($0)) },
            masteredCount: child.masteredUnlockedCount,
            learningCount: letters.count { mastery($0) == .learning },
            // Counted from the currently-unlocked set rather than by
            // subtracting the other two — stored progress is not age-gated,
            // so a parent lowering a child's age used to drive this negative.
            notStartedCount: letters.count { mastery($0) == .new },
            needsPractice: child.progress
                .filter { $0.attempts >= 2 && $0.accuracy < 0.6 }
                .sorted { $0.accuracy < $1.accuracy }
                .prefix(5)
                .compactMap { $0.letter?.uppercase }
        )
    }

    var numberSummary: DomainSummary {
        let numbers = child.unlockedNumbers
        let mastery = { (number: NumberItem) in self.child.numberProgress(for: number.id)?.mastery ?? .new }

        return DomainSummary(
            id: "numbers",
            title: "Number mastery",
            practiceTitle: "Numbers worth practising together",
            practiceAdvice: "These come up wrong most often. Counting things around the house helps more than extra screen time.",
            cells: numbers.map { .init(id: "\($0.id)", label: "\($0.id)", mastery: mastery($0)) },
            masteredCount: child.masteredUnlockedNumberCount,
            learningCount: numbers.count { mastery($0) == .learning },
            notStartedCount: numbers.count { mastery($0) == .new },
            needsPractice: child.numberProgress
                .filter { $0.attempts >= 2 && $0.accuracy < 0.6 }
                .sorted { $0.accuracy < $1.accuracy }
                .prefix(5)
                .compactMap { $0.number.map { number in "\(number.id)" } }
        )
    }

    var summaries: [DomainSummary] { [letterSummary, numberSummary] }

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

    /// Written through `SessionTimerService` rather than set directly on the
    /// model: this is the one setting a parent actively chooses, and a bare
    /// assignment left it to autosave, where a force-quit could lose it.
    var dailyLimitMinutes: Int {
        get { child.dailyLimitMinutes }
        set { sessionTimer.setDailyLimit(newValue, for: child) }
    }

    func limitLabel(_ minutes: Int) -> String {
        minutes == 0 ? "Off" : "\(minutes)m"
    }

    var sessionCount: Int { child.sessions.count }

    var totalStars: Int { child.starCount }
    var streak: Int { child.currentStreak }
}
