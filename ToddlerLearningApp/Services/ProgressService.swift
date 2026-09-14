//
//  ProgressService.swift
//  ToddlerLearningApp
//
//  Spec F1 + F2. Owns every mutation of `LetterProgress` and the adaptive
//  selection that decides which letter a child sees next. ViewModels ask this
//  service for the next letter; they never sample the alphabet themselves.
//

import Foundation
import OSLog
import SwiftData

/// Save failures are logged rather than surfaced: interrupting a child's
/// session for a write that SwiftData will retry on its next autosave costs
/// more than the failure does.
private let logger = Logger(subsystem: "com.toddlerlearningapp", category: "progress")

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

    /// Builds one multiple-choice question, scaled to how well the child knows
    /// the answer: a new letter gets 3 tiles, none shaped like it; a mastered
    /// one gets 5, up to two of them look-alikes (F beside E, R beside P) — so
    /// the game gets harder as the child gets better at it. `distractorCount`
    /// overrides the tile count; the look-alike rule still follows mastery.
    func makeQuestion(for child: ChildProfile,
                      excluding excluded: String? = nil,
                      distractorCount: Int? = nil) -> QuizQuestion? {
        guard let answer = nextLetter(for: child, excluding: excluded) else { return nil }

        let mastery = child.progress(for: answer.id)?.mastery ?? .new
        let count = distractorCount ?? Self.distractorCount(for: mastery)
        let lookAlikeIDs = AlphabetContent.lookAlikes(of: answer.id)

        // Distractors are drawn from the whole unlocked set so the wrong options
        // are still letters the child has plausibly seen.
        let others = child.unlockedLetters.filter { $0.id != answer.id }.shuffled()
        let lookAlikes = others.filter { lookAlikeIDs.contains($0.id) }
        let distinct = others.filter { !lookAlikeIDs.contains($0.id) }

        let chosenLookAlikes = Array(lookAlikes.prefix(Self.lookAlikeQuota(for: mastery)))
        // The remaining look-alikes only top the row up when too few distinct
        // letters are unlocked to fill it.
        let distractors = (chosenLookAlikes + distinct + lookAlikes.dropFirst(chosenLookAlikes.count))
            .prefix(count)

        let options = (Array(distractors) + [answer]).shuffled()
        return QuizQuestion(answer: answer,
                            picture: answer.pictures.randomElement() ?? answer.mainPicture,
                            options: options)
    }

    private static func distractorCount(for mastery: MasteryLevel) -> Int {
        switch mastery {
        case .new: 2
        case .learning: 3
        case .mastered: 4
        }
    }

    private static func lookAlikeQuota(for mastery: MasteryLevel) -> Int {
        switch mastery {
        case .new: 0
        case .learning: 1
        case .mastered: 2
        }
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

    /// Builds one quantity-matching question: `object` shown as many times as
    /// the correct count, plus up to 4 wrong numeral options, shuffled.
    func makeNumberQuestion(for child: ChildProfile,
                            excluding excluded: Int? = nil,
                            showing object: CountingObject,
                            distractorCount: Int = 4) -> NumberQuizQuestion? {
        guard let answer = nextNumber(for: child, excluding: excluded) else { return nil }

        let distractors = child.unlockedNumbers
            .map(\.id)
            .filter { $0 != answer.id }
            .shuffled()
            .prefix(distractorCount)

        let options = (Array(distractors) + [answer.id]).shuffled()
        return NumberQuizQuestion(answer: answer, object: object, options: options)
    }

    // MARK: - Tracing

    /// Returns the stored trace-progress for a letter or digit, creating it on
    /// first encounter. `letterID` is a `TraceItem.id` — see
    /// `TraceProgress.letterID`.
    @discardableResult
    func traceProgress(for child: ChildProfile, letterID: String) -> TraceProgress {
        if let existing = child.traceProgress(for: letterID) {
            return existing
        }
        let record = TraceProgress(letterID: letterID)
        context.insert(record)
        record.child = child
        return record
    }

    /// Records a trace attempt and applies promotion/demotion — same rules as
    /// the letter/number quiz domains above. `completed` is `true` for a
    /// letter or digit finished start to finish, `false` for "Try again" pressed
    /// with meaningful progress already made — see `TraceViewModel` for the
    /// exact threshold that counts as a miss rather than simply not attempted.
    func recordTrace(child: ChildProfile, letterID: String, completed: Bool) {
        apply(correct: completed, to: traceProgress(for: child, letterID: letterID))
        save()
    }

    // MARK: - Build the Word

    /// Saves the child's Build the Word level — see `WordBuildProgression` —
    /// so it carries over to their next visit. A no-op when it hasn't changed.
    func recordWordBuildLevel(_ levelIndex: Int, for child: ChildProfile) {
        guard child.wordBuildLevel != levelIndex else { return }
        child.wordBuildLevel = levelIndex
        save()
    }

    // MARK: - Shared mutation (letters, numbers and tracing apply identical rules)

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
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
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
extension TraceProgress: ProgressRecord {}

/// One multiple-choice question. A value type — it holds no persistent state.
struct QuizQuestion: Identifiable, Hashable {
    let id = UUID()
    let answer: Letter
    /// Shown only once the letter is found — see `LetterQuizDomain`.
    let picture: LetterPicture
    let options: [Letter]
}

/// One quantity-matching question: `object` shown `answer.id` times, plus the
/// numeral options (including the correct count) to choose from. The object
/// is picked independently of the count — see `CountingObjectDeck`.
struct NumberQuizQuestion: Identifiable, Hashable {
    let id = UUID()
    let answer: NumberItem
    let object: CountingObject
    let options: [Int]
}
