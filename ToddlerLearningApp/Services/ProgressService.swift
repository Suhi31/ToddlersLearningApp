//
//  ProgressService.swift
//  ToddlerLearningApp
//
//  Spec F1 + F2. Owns every mutation of `LetterProgress` and the adaptive
//  selection that decides which letter a child sees next. ViewModels ask this
//  service for the next letter; they never sample the alphabet themselves.
//

import Foundation
import SwiftData

@MainActor
final class ProgressService {

    /// Consecutive correct answers required to move up a mastery stage.
    private let promotionThreshold = 3

    /// Consecutive misses that drop a letter back a stage.
    private let demotionThreshold = 2

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Access

    /// Returns the stored progress for a letter, creating it on first encounter.
    @discardableResult
    func progress(for child: ChildProfile, letterID: String) -> LetterProgress {
        if let existing = child.progress(for: letterID) {
            return existing
        }
        let record = LetterProgress(letterID: letterID)
        context.insert(record)
        record.child = child
        return record
    }

    // MARK: - Recording

    /// Records a quiz answer and applies promotion/demotion.
    func record(child: ChildProfile, letterID: String, correct: Bool) {
        apply(correct: correct, to: progress(for: child, letterID: letterID))
        save()
    }

    /// Records passive exposure from the Learn screen. Seeing a letter nudges it
    /// out of `.new`, but only answering correctly can reach `.mastered`.
    func recordExposure(child: ChildProfile, letterID: String) {
        applyExposure(to: progress(for: child, letterID: letterID))
        save()
    }

    // MARK: - Adaptive selection

    /// Picks the next letter to quiz, weighted so that shaky letters recur about
    /// four times as often as mastered ones (spec F2).
    func nextLetter(for child: ChildProfile, excluding excluded: String? = nil) -> Letter? {
        weightedNext(from: child.unlockedLetters, excluding: excluded) {
            child.progress(for: $0.id)?.mastery ?? .new
        }
    }

    /// Builds one multiple-choice question: the answer plus `distractorCount`
    /// wrong options, shuffled.
    func makeQuestion(for child: ChildProfile,
                      excluding excluded: String? = nil,
                      distractorCount: Int = 4) -> QuizQuestion? {
        guard let answer = nextLetter(for: child, excluding: excluded) else { return nil }

        // Distractors are drawn from the whole unlocked set so the wrong options
        // are still letters the child has plausibly seen.
        let distractors = child.unlockedLetters
            .filter { $0.id != answer.id }
            .shuffled()
            .prefix(distractorCount)

        let options = (Array(distractors) + [answer]).shuffled()
        return QuizQuestion(answer: answer, options: options)
    }

    // MARK: - Numbers

    /// Returns the stored progress for a number, creating it on first encounter.
    @discardableResult
    func progress(for child: ChildProfile, numberID: Int) -> NumberProgress {
        if let existing = child.numberProgress(for: numberID) {
            return existing
        }
        let record = NumberProgress(numberID: numberID)
        context.insert(record)
        record.child = child
        return record
    }

    /// Records a quiz answer and applies promotion/demotion — same rules as
    /// the letter version above.
    func record(child: ChildProfile, numberID: Int, correct: Bool) {
        apply(correct: correct, to: progress(for: child, numberID: numberID))
        save()
    }

    /// Records passive exposure from the Learn Numbers screen.
    func recordExposure(child: ChildProfile, numberID: Int) {
        applyExposure(to: progress(for: child, numberID: numberID))
        save()
    }

    /// Picks the next number to quiz, weighted the same way `nextLetter` is.
    func nextNumber(for child: ChildProfile, excluding excluded: Int? = nil) -> NumberItem? {
        weightedNext(from: child.unlockedNumbers, excluding: excluded) {
            child.numberProgress(for: $0.id)?.mastery ?? .new
        }
    }

    /// Builds one quantity-matching question: the correct count plus up to 4
    /// wrong numeral options, shuffled.
    func makeNumberQuestion(for child: ChildProfile,
                            excluding excluded: Int? = nil,
                            distractorCount: Int = 4) -> NumberQuizQuestion? {
        guard let answer = nextNumber(for: child, excluding: excluded) else { return nil }

        let distractors = child.unlockedNumbers
            .map(\.id)
            .filter { $0 != answer.id }
            .shuffled()
            .prefix(distractorCount)

        let options = (Array(distractors) + [answer.id]).shuffled()
        return NumberQuizQuestion(answer: answer, options: options)
    }

    // MARK: - Shared mutation (letters and numbers apply identical rules)

    /// Applies one answer's promotion/demotion rules to either progress model.
    private func apply(correct: Bool, to record: ProgressRecord) {
        record.attempts += 1
        record.lastSeenAt = .now

        if correct {
            record.correctCount += 1
            record.consecutiveCorrect += 1
            record.consecutiveMisses = 0

            if record.consecutiveCorrect >= promotionThreshold {
                record.mastery = record.mastery.promoted
                record.consecutiveCorrect = 0
            }
        } else {
            record.consecutiveMisses += 1
            record.consecutiveCorrect = 0

            if record.consecutiveMisses >= demotionThreshold {
                record.mastery = record.mastery.demoted
                record.consecutiveMisses = 0
            }
        }
    }

    private func applyExposure(to record: ProgressRecord) {
        record.lastSeenAt = .now
        if record.mastery == .new {
            record.mastery = .learning
        }
    }

    /// Weighted random pick shared by `nextLetter`/`nextNumber`: shaky items
    /// recur more often than mastered ones, per `MasteryLevel.selectionWeight`.
    private func weightedNext<Item: Identifiable>(
        from unlocked: [Item],
        excluding excludedID: Item.ID?,
        mastery: (Item) -> MasteryLevel
    ) -> Item? {
        let candidates = unlocked.filter { $0.id != excludedID }
        guard !candidates.isEmpty else { return unlocked.first }

        var pool: [Item] = []
        for item in candidates {
            pool.append(contentsOf: repeatElement(item, count: mastery(item).selectionWeight))
        }
        return pool.randomElement()
    }

    // MARK: - Persistence

    private func save() {
        do {
            try context.save()
        } catch {
            // A failed save is not worth interrupting a child's session for;
            // SwiftData will retry on the next autosave.
            print("ProgressService save failed: \(error)")
        }
    }
}

/// Common shape of `LetterProgress` and `NumberProgress` — the two domains
/// only share the mastery *state machine*, which lives here so `ProgressService`
/// doesn't have to implement promotion/demotion twice.
private protocol ProgressRecord: AnyObject {
    var attempts: Int { get set }
    var correctCount: Int { get set }
    var consecutiveCorrect: Int { get set }
    var consecutiveMisses: Int { get set }
    var lastSeenAt: Date? { get set }
    var mastery: MasteryLevel { get set }
}

extension LetterProgress: ProgressRecord {}
extension NumberProgress: ProgressRecord {}

/// One multiple-choice question. A value type — it holds no persistent state.
struct QuizQuestion: Identifiable, Hashable {
    let id = UUID()
    let answer: Letter
    let options: [Letter]
}

/// One quantity-matching question: how many of `answer.emoji` are shown, plus
/// the numeral options (including the correct count) to choose from.
struct NumberQuizQuestion: Identifiable, Hashable {
    let id = UUID()
    let answer: NumberItem
    let options: [Int]
}
