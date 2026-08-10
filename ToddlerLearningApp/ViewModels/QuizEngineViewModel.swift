//
//  QuizEngineViewModel.swift
//  ToddlerLearningApp
//
//  Shared engine behind the letter quiz (spec F2) and the number quiz: show a
//  question, accept one tap, react with feedback + a star, then advance after
//  a delay. Question shape, scoring rule, and prompt copy differ per domain
//  (`QuizDomain`); the interaction rhythm — accept-input gating, feedback
//  timing, and the safe-stopping-point callback — is identical, so it lives
//  here once instead of twice.
//

import Foundation

enum QuizFeedbackState<Answer: Equatable>: Equatable {
    case none
    case correct
    case incorrect(Answer)
}

/// What a quiz domain needs to supply: how to read/record an answer for its
/// question type, how to turn what the child tapped into a comparable answer
/// (a letter tile passes the whole `Letter`; a number tile already passes the
/// bare `Int`), and how the prompt sounds.
protocol QuizDomain {
    associatedtype Question
    associatedtype Selection
    associatedtype Answer: Equatable

    func answer(for question: Question) -> Answer
    func answer(for selection: Selection) -> Answer
    func nextQuestion(for child: ChildProfile, excluding previous: Answer?) -> Question?
    func recordAnswer(child: ChildProfile, question: Question, correct: Bool)
    func promptSpeech(for question: Question) -> String
    func incorrectSpeech(for question: Question, speechService: SpeechServicing)
}

@MainActor
@Observable
final class QuizEngineViewModel<Domain: QuizDomain> {

    private(set) var question: Domain.Question?
    private(set) var feedback: QuizFeedbackState<Domain.Answer> = .none
    private(set) var starsThisSession: Int = 0

    /// Blocks further taps while feedback is playing, so a child mashing tiles
    /// cannot bank several answers against one question.
    private(set) var isAcceptingInput: Bool = true

    /// Fired after each answered question — a natural break where the daily
    /// allowance may end the session (spec F5). The view wires this to the
    /// coordinator; the ViewModel stays navigation-agnostic.
    var onSafeStoppingPoint: (() -> Void)?

    let child: ChildProfile
    private let domain: Domain
    private let speechService: SpeechServicing
    private let rewardService: RewardService
    private let haptics: HapticsService

    private var advanceTask: Task<Void, Never>?

    deinit {}

    init(child: ChildProfile,
         domain: Domain,
         speechService: SpeechServicing,
         rewardService: RewardService,
         haptics: HapticsService) {
        self.child = child
        self.domain = domain
        self.speechService = speechService
        self.rewardService = rewardService
        self.haptics = haptics
    }

    // MARK: - Lifecycle

    func onAppear() {
        haptics.prepare()
        if question == nil {
            loadNextQuestion()
        }
    }

    func onDisappear() {
        advanceTask?.cancel()
        speechService.stop()
    }

    // MARK: - Intent

    func select(_ selection: Domain.Selection) {
        guard isAcceptingInput, let question else { return }

        isAcceptingInput = false
        let picked = domain.answer(for: selection)
        let isCorrect = picked == domain.answer(for: question)
        domain.recordAnswer(child: child, question: question, correct: isCorrect)

        if isCorrect {
            feedback = .correct
            starsThisSession += 1
            rewardService.awardStars(1, to: child)
            haptics.success()
            speechService.praise(childName: child.name)
        } else {
            feedback = .incorrect(picked)
            haptics.gentleMiss()
            domain.incorrectSpeech(for: question, speechService: speechService)
        }

        advanceTask?.cancel()
        advanceTask = Task { [weak self, isCorrect] in
            // Long enough for the spoken line to land before the screen changes.
            try? await Task.sleep(for: .seconds(isCorrect ? 1.6 : 2.2))
            guard !Task.isCancelled else { return }
            self?.advance(afterCorrectAnswer: isCorrect)
        }
    }

    func repeatPrompt() {
        guard let question else { return }
        speechService.speak(domain.promptSpeech(for: question))
    }

    // MARK: - Flow

    private func advance(afterCorrectAnswer wasCorrect: Bool) {
        feedback = .none
        isAcceptingInput = true

        if wasCorrect {
            loadNextQuestion()
        }
        // A miss keeps the same question on screen: the child has just been told
        // the answer, and getting it right immediately afterwards is the point.

        onSafeStoppingPoint?()
    }

    private func loadNextQuestion() {
        let previous = question.map(domain.answer(for:))
        question = domain.nextQuestion(for: child, excluding: previous)

        if let question {
            speechService.speak(domain.promptSpeech(for: question))
        }
    }
}

// MARK: - Letter quiz (spec F2)

/// The child sees a picture and picks the letter it starts with.
struct LetterQuizDomain: QuizDomain {
    typealias Question = QuizQuestion
    typealias Selection = Letter
    typealias Answer = String

    let progressService: ProgressService

    func answer(for question: QuizQuestion) -> String { question.answer.id }
    func answer(for selection: Letter) -> String { selection.id }

    func nextQuestion(for child: ChildProfile, excluding previous: String?) -> QuizQuestion? {
        progressService.makeQuestion(for: child, excluding: previous)
    }

    func recordAnswer(child: ChildProfile, question: QuizQuestion, correct: Bool) {
        progressService.record(child: child, letterID: question.answer.id, correct: correct)
    }

    func promptSpeech(for question: QuizQuestion) -> String {
        "Which letter does \(question.answer.word) start with?"
    }

    func incorrectSpeech(for question: QuizQuestion, speechService: SpeechServicing) {
        speechService.encourage(question.answer)
    }
}

typealias QuizViewModel = QuizEngineViewModel<LetterQuizDomain>
typealias QuizFeedback = QuizFeedbackState<String>

extension QuizEngineViewModel where Domain == LetterQuizDomain {

    convenience init(child: ChildProfile,
                      speechService: SpeechServicing,
                      progressService: ProgressService,
                      rewardService: RewardService,
                      haptics: HapticsService) {
        self.init(
            child: child,
            domain: LetterQuizDomain(progressService: progressService),
            speechService: speechService,
            rewardService: rewardService,
            haptics: haptics
        )
    }

    var promptEmoji: String { question?.answer.emojis.first ?? "❓" }
    var promptWord: String { question?.answer.word ?? "" }
}

// MARK: - Number quiz

/// The child sees a *quantity* (N copies of an emoji) and taps the matching
/// numeral, rather than picking a letter that starts a word — that's the
/// actual counting pedagogy, not just new data plugged into the letter shape.
struct NumberQuizDomain: QuizDomain {
    typealias Question = NumberQuizQuestion
    typealias Selection = Int
    typealias Answer = Int

    let progressService: ProgressService

    func answer(for question: NumberQuizQuestion) -> Int { question.answer.id }
    func answer(for selection: Int) -> Int { selection }

    func nextQuestion(for child: ChildProfile, excluding previous: Int?) -> NumberQuizQuestion? {
        progressService.makeNumberQuestion(for: child, excluding: previous)
    }

    func recordAnswer(child: ChildProfile, question: NumberQuizQuestion, correct: Bool) {
        progressService.record(child: child, numberID: question.answer.id, correct: correct)
    }

    func promptSpeech(for question: NumberQuizQuestion) -> String {
        "How many do you see?"
    }

    func incorrectSpeech(for question: NumberQuizQuestion, speechService: SpeechServicing) {
        speechService.speak("This one is \(question.answer.name). Let's try again.")
    }
}

typealias NumberQuizViewModel = QuizEngineViewModel<NumberQuizDomain>
typealias NumberQuizFeedback = QuizFeedbackState<Int>

extension QuizEngineViewModel where Domain == NumberQuizDomain {

    convenience init(child: ChildProfile,
                      speechService: SpeechServicing,
                      progressService: ProgressService,
                      rewardService: RewardService,
                      haptics: HapticsService) {
        self.init(
            child: child,
            domain: NumberQuizDomain(progressService: progressService),
            speechService: speechService,
            rewardService: rewardService,
            haptics: haptics
        )
    }

    var promptEmoji: String { question?.answer.emoji ?? "❓" }
    var promptCount: Int { question?.answer.id ?? 0 }
}
