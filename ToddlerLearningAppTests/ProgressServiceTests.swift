//
//  ProgressServiceTests.swift
//  ToddlerLearningAppTests
//
//  The mastery state machine (spec F2) is the one piece of logic in this app
//  where a silent regression is invisible in the UI — a letter promoted one
//  answer too early still looks fine on screen, it just stops being practised.
//  These tests pin the promotion/demotion rules, the streak-reset behaviour
//  that makes them meaningful, and the age gate they run inside.
//

import Foundation
import SwiftData
import Testing

@testable import ToddlerLearningApp

@MainActor
struct ProgressServiceTests {

    // MARK: - Fixture

    /// A fresh in-memory stack per test, so no test can observe another's writes.
    private static func makeService(childAge: Int = 4) throws -> (ProgressService, ChildProfile) {
        let container = try ModelContainer(
            for: ChildProfile.self, LetterProgress.self, NumberProgress.self, TraceProgress.self, SessionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // A plain `ModelContext(container)`, not `container.mainContext`: the
        // latter observes app-lifecycle notifications to autosave/reset itself,
        // and the test host process backgrounds almost immediately since it
        // never really presents UI — which was enough to trigger SwiftData's
        // "This model instance was destroyed by calling ModelContext.reset"
        // fatal error mid-test. The production code's own use of
        // `container.mainContext` (AppDependencies) is unaffected; that runs
        // inside a real, foregrounded app.
        let context = ModelContext(container)
        let child = ChildProfile(name: "Test", age: childAge, avatarEmoji: "🐰")
        context.insert(child)
        return (ProgressService(context: context), child)
    }

    private static func answer(_ service: ProgressService,
                               _ child: ChildProfile,
                               correct: Bool,
                               times: Int = 1,
                               letterID: String = "A") {
        for _ in 0..<times {
            service.record(child: child, letterID: letterID, correct: correct)
        }
    }

    // MARK: - Promotion

    @Test("Three consecutive correct answers promote a new letter to learning")
    func promotesAfterThreeCorrect() throws {
        let (service, child) = try Self.makeService()

        Self.answer(service, child, correct: true, times: 2)
        #expect(service.progress(for: child, letterID: "A").mastery == .new,
                "Two correct answers must not be enough to promote")

        Self.answer(service, child, correct: true)
        #expect(service.progress(for: child, letterID: "A").mastery == .learning)
    }

    @Test("Six consecutive correct answers reach mastered")
    func promotesTwiceToMastered() throws {
        let (service, child) = try Self.makeService()

        Self.answer(service, child, correct: true, times: 6)
        #expect(service.progress(for: child, letterID: "A").mastery == .mastered)
    }

    @Test("The correct streak resets on promotion, so each stage costs three more")
    func streakResetsAfterPromotion() throws {
        let (service, child) = try Self.makeService()

        Self.answer(service, child, correct: true, times: 5)
        #expect(service.progress(for: child, letterID: "A").mastery == .learning,
                "Five correct is one short of the second promotion")
    }

    @Test("Mastery does not climb past mastered")
    func masteryCeiling() throws {
        let (service, child) = try Self.makeService()

        Self.answer(service, child, correct: true, times: 30)
        #expect(service.progress(for: child, letterID: "A").mastery == .mastered)
    }

    // MARK: - Demotion

    @Test("Two consecutive misses drop a letter one stage")
    func demotesAfterTwoMisses() throws {
        let (service, child) = try Self.makeService()

        Self.answer(service, child, correct: true, times: 3)
        #expect(service.progress(for: child, letterID: "A").mastery == .learning)

        Self.answer(service, child, correct: false)
        #expect(service.progress(for: child, letterID: "A").mastery == .learning,
                "One miss must not demote")

        Self.answer(service, child, correct: false)
        #expect(service.progress(for: child, letterID: "A").mastery == .new)
    }

    @Test("Mastery does not fall below new")
    func masteryFloor() throws {
        let (service, child) = try Self.makeService()

        Self.answer(service, child, correct: false, times: 20)
        #expect(service.progress(for: child, letterID: "A").mastery == .new)
    }

    // MARK: - Streak interaction
    //
    // These two are the tests that give the thresholds meaning: without them a
    // cumulative counter would pass every test above while behaving completely
    // differently for a child who is guessing.

    @Test("A miss resets the correct streak")
    func missResetsCorrectStreak() throws {
        let (service, child) = try Self.makeService()

        Self.answer(service, child, correct: true, times: 2)
        Self.answer(service, child, correct: false)
        Self.answer(service, child, correct: true, times: 2)

        #expect(service.progress(for: child, letterID: "A").mastery == .new,
                "Four correct answers split by a miss must not promote")
    }

    @Test("A correct answer resets the miss streak")
    func correctResetsMissStreak() throws {
        let (service, child) = try Self.makeService()

        Self.answer(service, child, correct: true, times: 3)   // → .learning
        Self.answer(service, child, correct: false)
        Self.answer(service, child, correct: true)
        Self.answer(service, child, correct: false)

        #expect(service.progress(for: child, letterID: "A").mastery == .learning,
                "Two misses split by a correct answer must not demote")
    }

    // MARK: - Accounting

    @Test("Attempts, correct count, and accuracy track every answer")
    func recordsAttemptAccounting() throws {
        let (service, child) = try Self.makeService()

        Self.answer(service, child, correct: true, times: 3)
        Self.answer(service, child, correct: false)

        let record = service.progress(for: child, letterID: "A")
        #expect(record.attempts == 4)
        #expect(record.correctCount == 3)
        #expect(record.accuracy == 0.75)
        #expect(record.lastSeenAt != nil)
    }

    @Test("Accuracy is zero before any attempt rather than dividing by zero")
    func accuracyWithNoAttempts() throws {
        let (service, child) = try Self.makeService()

        #expect(service.progress(for: child, letterID: "A").accuracy == 0)
    }

    @Test("Progress is created once and reused for the same letter")
    func progressRecordIsStable() throws {
        let (service, child) = try Self.makeService()

        let first = service.progress(for: child, letterID: "A")
        first.attempts = 7
        let second = service.progress(for: child, letterID: "A")

        #expect(first === second)
        #expect(second.attempts == 7)
        #expect(child.progress.count == 1)
    }

    @Test("Each letter keeps independent progress")
    func lettersAreIndependent() throws {
        let (service, child) = try Self.makeService()

        Self.answer(service, child, correct: true, times: 3, letterID: "A")

        #expect(service.progress(for: child, letterID: "A").mastery == .learning)
        #expect(service.progress(for: child, letterID: "B").mastery == .new)
    }

    // MARK: - Exposure

    @Test("Seeing a letter nudges it out of new")
    func exposurePromotesFromNew() throws {
        let (service, child) = try Self.makeService()

        service.recordExposure(child: child, letterID: "A")

        let record = service.progress(for: child, letterID: "A")
        #expect(record.mastery == .learning)
        #expect(record.attempts == 0, "Exposure is not an attempt")
    }

    @Test("Exposure never reaches mastered — only correct answers do")
    func exposureDoesNotMaster() throws {
        let (service, child) = try Self.makeService()

        for _ in 0..<10 { service.recordExposure(child: child, letterID: "A") }

        #expect(service.progress(for: child, letterID: "A").mastery == .learning)
    }

    @Test("Exposure does not demote an already-mastered letter")
    func exposureLeavesMasteredAlone() throws {
        let (service, child) = try Self.makeService()

        Self.answer(service, child, correct: true, times: 6)
        service.recordExposure(child: child, letterID: "A")

        #expect(service.progress(for: child, letterID: "A").mastery == .mastered)
    }

    // MARK: - Selection

    @Test("The excluded letter is never offered next")
    func nextLetterHonoursExclusion() throws {
        let (service, child) = try Self.makeService()

        // Sampling is weighted-random, so this asserts over many draws.
        for _ in 0..<200 {
            let next = service.nextLetter(for: child, excluding: "A")
            #expect(next?.id != "A")
        }
    }

    @Test("A question contains its answer plus the requested distractors")
    func questionShape() throws {
        let (service, child) = try Self.makeService()

        let question = try #require(service.makeQuestion(for: child, distractorCount: 3))

        #expect(question.options.count == 4)
        #expect(question.options.contains(question.answer))
        #expect(Set(question.options.map(\.id)).count == question.options.count,
                "Options must not repeat")
    }

    @Test("Distractor count is capped by the unlocked set")
    func questionShapeRespectsSmallPool() throws {
        let (service, child) = try Self.makeService(childAge: 2)

        let question = try #require(service.makeQuestion(for: child, distractorCount: 40))

        #expect(question.options.count == child.unlockedLetters.count)
        #expect(question.options.contains(question.answer))
    }

    // MARK: - Age gate

    @Test("Under-threes see ten letters; from three, the whole alphabet",
          arguments: [(2, 10), (3, 26), (5, 26)])
    func ageGate(age: Int, expected: Int) throws {
        let (_, child) = try Self.makeService(childAge: age)

        #expect(child.unlockedLetters.count == expected)
    }

    @Test("Only unlocked letters count toward the progress shown on Home")
    func masteredCountIsGatedSeparatelyFromTrophies() throws {
        let (service, child) = try Self.makeService(childAge: 4)

        // Master a letter outside the under-three set, then lower the age —
        // the regression that once rendered "26 of 10 letters mastered".
        Self.answer(service, child, correct: true, times: 6, letterID: "Z")
        child.age = 2

        #expect(child.masteredCount == 1, "Trophy progress is never un-earned")
        #expect(child.masteredUnlockedCount == 0, "Z is outside the age-gated set")
        #expect(child.masteredUnlockedCount <= child.unlockedLetters.count)
    }

    // MARK: - Numbers parity
    //
    // Letters and numbers deliberately share one state machine. These tests
    // exist to catch the two drifting apart, not to re-prove the rules.

    @Test("Numbers promote on the same threshold as letters")
    func numberPromotion() throws {
        let (service, child) = try Self.makeService()

        for _ in 0..<3 { service.record(child: child, numberID: 1, correct: true) }
        #expect(service.progress(for: child, numberID: 1).mastery == .learning)

        for _ in 0..<3 { service.record(child: child, numberID: 1, correct: true) }
        #expect(service.progress(for: child, numberID: 1).mastery == .mastered)
    }

    @Test("Numbers demote on the same threshold as letters")
    func numberDemotion() throws {
        let (service, child) = try Self.makeService()

        for _ in 0..<3 { service.record(child: child, numberID: 1, correct: true) }
        for _ in 0..<2 { service.record(child: child, numberID: 1, correct: false) }

        #expect(service.progress(for: child, numberID: 1).mastery == .new)
    }

    @Test("Under-threes see five numbers; from three, all ten",
          arguments: [(2, 5), (3, 10), (5, 10)])
    func numberAgeGate(age: Int, expected: Int) throws {
        let (_, child) = try Self.makeService(childAge: age)

        #expect(child.unlockedNumbers.count == expected)
    }

    @Test("A number question contains its answer")
    func numberQuestionShape() throws {
        let (service, child) = try Self.makeService()

        let question = try #require(service.makeNumberQuestion(for: child, distractorCount: 3))

        #expect(question.options.count == 4)
        #expect(question.options.contains(question.answer.id))
        #expect(Set(question.options).count == question.options.count)
    }

    // MARK: - Tracing parity
    //
    // Tracing (spec F28) shares the same state machine too — see
    // `ProgressRecord` in ProgressService. These tests exist to catch tracing
    // drifting from the other two domains, not to re-prove the rules. There is
    // no tracing "question shape" test — unlike letters/numbers, tracing has
    // no quiz question to build; `recordTrace(completed:)` is the whole API.

    @Test("Tracing promotes on the same threshold as letters and numbers")
    func tracePromotion() throws {
        let (service, child) = try Self.makeService()

        for _ in 0..<3 { service.recordTrace(child: child, letterID: "A", completed: true) }
        #expect(service.traceProgress(for: child, letterID: "A").mastery == .learning)

        for _ in 0..<3 { service.recordTrace(child: child, letterID: "A", completed: true) }
        #expect(service.traceProgress(for: child, letterID: "A").mastery == .mastered)
    }

    @Test("Tracing demotes on the same threshold as letters and numbers")
    func traceDemotion() throws {
        let (service, child) = try Self.makeService()

        for _ in 0..<3 { service.recordTrace(child: child, letterID: "A", completed: true) }
        for _ in 0..<2 { service.recordTrace(child: child, letterID: "A", completed: false) }

        #expect(service.traceProgress(for: child, letterID: "A").mastery == .new)
    }

    @Test("Trace mastery is gated separately from trophies, same as letters")
    func traceMasteredCountIsGatedSeparatelyFromTrophies() throws {
        let (service, child) = try Self.makeService(childAge: 4)

        // Master a letter outside the under-three set, then lower the age —
        // the same regression `masteredCountIsGatedSeparatelyFromTrophies`
        // guards against for letters, checked here for tracing too.
        for _ in 0..<6 { service.recordTrace(child: child, letterID: "Z", completed: true) }
        child.age = 2

        #expect(child.masteredTraceCount == 1, "Trophy progress is never un-earned")
        #expect(child.masteredUnlockedTraceCount == 0, "Z is outside the age-gated set")
        #expect(child.masteredUnlockedTraceCount <= child.unlockedLetters.count)
    }
}
