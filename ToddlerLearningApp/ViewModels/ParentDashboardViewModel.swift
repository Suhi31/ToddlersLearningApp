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

    /// Spec F28. Tracing-domain twin of `letterSummary` — gated to the same
    /// `unlockedLetters` set as the quiz/recognition summary above, for a
    /// consistent picture across every mastery section on this dashboard,
    /// even though the Trace activity itself doesn't currently age-gate
    /// which letters a child can trace.
    var traceSummary: DomainSummary {
        let letters = child.unlockedLetters
        let mastery = { (letter: Letter) in self.child.traceProgress(for: letter.id)?.mastery ?? .new }

        return DomainSummary(
            id: "tracing",
            title: "Letter tracing mastery",
            practiceTitle: "Worth practising together",
            practiceAdvice: "These come up shaky most often. A pencil and paper alongside the app helps more than extra screen time.",
            cells: letters.map { .init(id: $0.id, label: $0.uppercase, mastery: mastery($0)) },
            masteredCount: child.masteredUnlockedTraceCount,
            learningCount: letters.count { mastery($0) == .learning },
            notStartedCount: letters.count { mastery($0) == .new },
            needsPractice: child.traceProgress
                .filter { $0.attempts >= 2 && $0.accuracy < 0.6 }
                .sorted { $0.accuracy < $1.accuracy }
                .prefix(5)
                .compactMap { $0.letter?.uppercase }
        )
    }

    /// Trace Numbers' twin of `traceSummary`. Every digit, 0–9, with no age
    /// gate: the activity offers all ten, and there is no unlocked set of
    /// digits to gate against — `unlockedNumbers` is counting 1–10.
    var numberTraceSummary: DomainSummary {
        let digits = TraceKind.numbers.items
        let digitIDs = Set(digits.map(\.id))
        let mastery = { (digit: TraceItem) in self.child.traceProgress(for: digit.id)?.mastery ?? .new }

        return DomainSummary(
            id: "numberTracing",
            title: "Number tracing mastery",
            practiceTitle: "Numbers worth tracing together",
            practiceAdvice: "These come up shaky most often. Writing real numbers on paper together — an age on a birthday card, the house number — helps more than extra screen time.",
            cells: digits.map { .init(id: $0.id, label: $0.glyph, mastery: mastery($0)) },
            masteredCount: digits.count { mastery($0) == .mastered },
            learningCount: digits.count { mastery($0) == .learning },
            notStartedCount: digits.count { mastery($0) == .new },
            needsPractice: child.traceProgress
                .filter { digitIDs.contains($0.letterID) && $0.attempts >= 2 && $0.accuracy < 0.6 }
                .sorted { $0.accuracy < $1.accuracy }
                .prefix(5)
                .map(\.letterID)
        )
    }

    var summaries: [DomainSummary] { [letterSummary, numberSummary, traceSummary, numberTraceSummary] }

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

    /// Windowed to the same 7 days as `weeklyTotals`, not all-time — see
    /// `SessionTimerService.sessionCount(for:days:)`.
    var sessionCount: Int { SessionTimerService.sessionCount(for: child) }

    var totalStars: Int { child.starCount }
    var streak: Int { child.currentStreak }
}
