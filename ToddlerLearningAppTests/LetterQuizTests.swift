//
//  LetterQuizTests.swift
//  ToddlerLearningAppTests
//
//  The letter quiz is only a test of knowing the letter if nothing else gives
//  it away: not the written word, not a free retry, not tiles too easy to
//  tell apart. These pin the rules that keep it that way — scoring, reveal
//  timing and difficulty scaling.
//

import Foundation
import SwiftData
import Testing

@testable import ToddlerLearningApp

@MainActor
struct LetterQuizTests {

    // MARK: - Fixture

    private static func makeContext(childAge: Int = 4) throws -> (ModelContext, ChildProfile) {
        let container = try ModelContainer(
            for: ChildProfile.self, LetterProgress.self, NumberProgress.self, TraceProgress.self, SessionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // Not `container.mainContext` — see `ProgressServiceTests.makeService`.
        let context = ModelContext(container)
        let child = ChildProfile(name: "Test", age: childAge, avatarEmoji: "🐰")
        context.insert(child)
        return (context, child)
    }

    /// `speech` is optional rather than defaulting to `SilentSpeech()`: a
    /// default argument is evaluated outside the main actor that type needs.
    private static func makeQuiz(speech: SpeechServicing? = nil) throws
        -> (QuizViewModel, ProgressService, ChildProfile) {
        let (context, child) = try makeContext()
        let progress = ProgressService(context: context)
        let quiz = QuizViewModel(child: child,
                                 domain: LetterQuizDomain(progressService: progress),
                                 speechService: speech ?? SilentSpeech(),
                                 rewardService: RewardService(context: context),
                                 haptics: HapticsService(),
                                 minimumFeedbackTime: .zero)
        quiz.onAppear()
        return (quiz, progress, child)
    }

    /// Feedback ends on a short timer even with nothing spoken.
    private static func waitForInput(_ quiz: QuizViewModel) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !quiz.isAcceptingInput {
            guard ContinuousClock.now < deadline else {
                Issue.record("The quiz never accepted input again")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func wrongOption(_ quiz: QuizViewModel) throws -> Letter {
        try #require(quiz.options.first { quiz.answer(for: $0) != quiz.currentAnswer })
    }

    private static func rightOption(_ quiz: QuizViewModel) throws -> Letter {
        try #require(quiz.options.first { quiz.answer(for: $0) == quiz.currentAnswer })
    }

    // MARK: - Scoring

    @Test("A correct first try counts toward mastery and earns a star")
    func firstTryCounts() throws {
        let (quiz, progress, child) = try Self.makeQuiz()
        let letterID = try #require(quiz.currentAnswer)

        quiz.select(try Self.rightOption(quiz))

        #expect(progress.progress(for: child, letterID: letterID).correctCount == 1)
        #expect(child.starCount == 1)
        #expect(quiz.starsThisRound == 1)
    }

    @Test("A retry after a miss neither counts toward mastery nor earns a star")
    func retryDoesNotCount() async throws {
        let (quiz, progress, child) = try Self.makeQuiz()
        let letterID = try #require(quiz.currentAnswer)

        quiz.select(try Self.wrongOption(quiz))
        try await Self.waitForInput(quiz)
        quiz.select(try Self.rightOption(quiz))

        let record = progress.progress(for: child, letterID: letterID)
        #expect(record.attempts == 1, "Only the first tap is recorded")
        #expect(record.correctCount == 0)
        #expect(record.consecutiveMisses == 1, "The retry must not wipe out the miss")
        #expect(child.starCount == 0)
        #expect(quiz.feedback == .correct)
    }

    @Test("The first miss reveals nothing; the second lights up the answer and moves it")
    func revealWaitsForSecondMiss() async throws {
        let (quiz, _, _) = try Self.makeQuiz()
        let isAnswer: (Letter) -> Bool = { quiz.answer(for: $0) == quiz.currentAnswer }

        quiz.select(try Self.wrongOption(quiz))
        #expect(!quiz.isAnswerRevealed)
        try await Self.waitForInput(quiz)

        let spotBeforeReveal = quiz.options.firstIndex(where: isAnswer)
        quiz.select(try Self.wrongOption(quiz))
        #expect(quiz.isAnswerRevealed)
        try await Self.waitForInput(quiz)

        #expect(quiz.options.firstIndex(where: isAnswer) != spotBeforeReveal)
    }

    // MARK: - Replay

    @Test("Tapping to hear the question again does nothing while it's still being spoken")
    func replayWaitsForPromptToFinish() async throws {
        let speech = HeldSpeech()
        let (quiz, _, _) = try Self.makeQuiz(speech: speech)
        try await waitUntil { speech.lines.count == 1 }
        #expect(quiz.isPromptPlaying)

        quiz.repeatPrompt()
        quiz.repeatPrompt()
        await Task.yield()
        #expect(speech.lines.count == 1, "Replays mid-question must not restart it")

        speech.finishAll()
        try await waitUntil { !quiz.isPromptPlaying }
        quiz.repeatPrompt()
        try await waitUntil { speech.lines.count == 2 }
    }

    // MARK: - Difficulty

    @Test("A new letter gets three tiles, none shaped like it")
    func newLetterIsEasy() throws {
        let (context, child) = try Self.makeContext()
        let service = ProgressService(context: context)

        for _ in 0..<30 {
            let question = try #require(service.makeQuestion(for: child))
            let lookAlikes = AlphabetContent.lookAlikes(of: question.answer.id)

            #expect(question.options.count == 3)
            #expect(!question.options.contains { lookAlikes.contains($0.id) })
        }
    }

    @Test("A mastered letter gets five tiles, including up to two look-alikes")
    func masteredLetterIsHarder() throws {
        let (context, child) = try Self.makeContext()
        let service = ProgressService(context: context)
        for letter in AlphabetContent.letters {
            for _ in 0..<6 { service.record(child: child, letterID: letter.id, correct: true) }
        }

        for _ in 0..<30 {
            let question = try #require(service.makeQuestion(for: child))
            let lookAlikes = AlphabetContent.lookAlikes(of: question.answer.id)
            let offered = question.options.filter { lookAlikes.contains($0.id) }

            #expect(question.options.count == 5)
            #expect(offered.count == min(2, lookAlikes.count), "for \(question.answer.id)")
        }
    }

    @Test("Look-alikes go both ways")
    func lookAlikesAreSymmetric() {
        for letter in AlphabetContent.letters {
            for other in AlphabetContent.lookAlikes(of: letter.id) {
                #expect(AlphabetContent.lookAlikes(of: other).contains(letter.id), "\(letter.id)–\(other)")
            }
        }
    }

    // MARK: - Speech

    /// "That's I. A is for Ant" gets read as the initials "I. A." with no
    /// pause, so no spoken sentence may carry on past a lone letter — it has
    /// to end there, to get its own gap.
    @Test("No spoken sentence runs on past a lone letter")
    func sentencesBreakAfterLoneLetters() throws {
        let (context, child) = try Self.makeContext()
        let domain = LetterQuizDomain(progressService: ProgressService(context: context))
        let runOn = try NSRegularExpression(pattern: #"(?<![\p{L}'’])[A-Z][.!?]\s+\S"#)

        for _ in 0..<40 {
            let question = try #require(domain.nextQuestion(for: child, excluding: nil))
            let picked = try #require(question.options.first { $0 != question.answer })
            let lines = [
                [domain.promptSpeech(for: question)],
                domain.correctSpeech(for: question, isFirstTry: true, childName: "Mih"),
                domain.correctSpeech(for: question, isFirstTry: false, childName: ""),
                domain.incorrectSpeech(for: question, picked: picked, misses: 1),
                domain.incorrectSpeech(for: question, picked: picked, misses: 2)
            ]
            for sentence in lines.joined() {
                let range = NSRange(location: 0, length: (sentence as NSString).length)
                #expect(runOn.firstMatch(in: sentence, range: range) == nil, "\(sentence)")
            }
        }
    }

    // MARK: - Content

    @Test("Every picture's word starts with its letter")
    func picturesMatchTheirLetter() {
        for letter in AlphabetContent.letters {
            #expect(!letter.pictures.isEmpty)
            for picture in letter.pictures {
                #expect(picture.word.uppercased().hasPrefix(letter.id), "\(picture.word) for \(letter.id)")
            }
        }
    }
}

/// Polls `condition` on the main actor until it holds, for state that settles
/// a task hop or two later.
@MainActor
func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(3)
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Condition never became true")
            return
        }
        try await Task.sleep(for: .milliseconds(20))
    }
}

/// Keeps every `speakAndWait` line "playing" until `finishAll()`, and records
/// what was said — for checking what happens mid-line.
@MainActor
final class HeldSpeech: SpeechServicing {
    private(set) var lines: [[String]] = []
    private var playing: [CheckedContinuation<Void, Never>] = []

    func speak(_ text: String) { lines.append([text]) }

    func speakAndWait(_ sentences: [String]) async {
        lines.append(sentences)
        await withCheckedContinuation { playing.append($0) }
    }

    func teachLetter(_ letter: Letter) async {}
    func teachNumber(_ number: NumberItem) async {}
    func stop() {}

    func finishAll() {
        let finished = playing
        playing = []
        finished.forEach { $0.resume() }
    }
}

/// Returns straight away from everything, so the quiz's own timing is all
/// that's left to wait on.
@MainActor
private final class SilentSpeech: SpeechServicing {
    func speak(_ text: String) {}
    func speakAndWait(_ sentences: [String]) async {}
    func teachLetter(_ letter: Letter) async {}
    func teachNumber(_ number: NumberItem) async {}
    func stop() {}
}
