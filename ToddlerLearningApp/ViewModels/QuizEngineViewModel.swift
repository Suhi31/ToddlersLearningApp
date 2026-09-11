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
    /// `Hashable` so the option grid can identify tiles by value rather than
    /// by position — positional identity would morph one question's tiles into
    /// the next question's instead of replacing them.
    associatedtype Selection: Hashable
    associatedtype Answer: Equatable

    func answer(for question: Question) -> Answer
    func answer(for selection: Selection) -> Answer

    /// The tappable options for a question, in display order.
    func options(for question: Question) -> [Selection]
    func nextQuestion(for child: ChildProfile, excluding previous: Answer?) -> Question?
    func recordAnswer(child: ChildProfile, question: Question, correct: Bool)
    func promptSpeech(for question: Question) -> String

    /// What to say after a correct tap, as sentences spoken with a short gap
    /// between them — see `SpeechServicing.speakAndWait`. `isFirstTry` is
    /// false once the child has missed this question — still worth praising,
    /// but it's a retry, not an answer they knew.
    func correctSpeech(for question: Question, isFirstTry: Bool, childName: String) -> [String]

    /// What to say after the `misses`-th wrong tap on one question, in the
    /// same form as `correctSpeech`.
    func incorrectSpeech(for question: Question, picked: Selection, misses: Int) -> [String]

    /// Whether the right tile lights up after `misses` wrong taps on one question.
    func revealsAnswer(afterMisses misses: Int) -> Bool
}

@MainActor
@Observable
final class QuizEngineViewModel<Domain: QuizDomain> {

    /// Correct answers needed to complete a round (spec F27) — a finish line
    /// rather than the quiz running forever until the child backs out.
    let questionsPerRound: Int

    private(set) var question: Domain.Question?
    private(set) var feedback: QuizFeedbackState<Domain.Answer> = .none
    private(set) var starsThisSession: Int = 0

    /// Stars earned in the current round, for the round-complete screen. Not
    /// `questionsAnswered`: a correct retry after a miss finishes a question
    /// without earning a star.
    private(set) var starsThisRound: Int = 0

    /// Correct answers so far in the current round. A miss keeps the same
    /// question on screen and doesn't advance this — see `select(_:)`.
    private(set) var questionsAnswered: Int = 0

    /// Set once `questionsAnswered` reaches `questionsPerRound`. The view
    /// shows a celebration instead of the next question; `startNewRound()`
    /// clears it and begins again.
    private(set) var isRoundComplete: Bool = false

    /// Blocks further taps while feedback is playing, so a child mashing tiles
    /// cannot bank several answers against one question.
    private(set) var isAcceptingInput: Bool = true

    /// Whether the current miss lights up the right tile. The domain decides —
    /// the letter quiz holds it back until a second miss, so the first retry is
    /// still the child's own look. Only meaningful while `feedback` is
    /// `.incorrect`.
    private(set) var isAnswerRevealed = false

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

    /// Wrong taps on the current question so far — see `select(_:)`.
    private var missesOnQuestion = 0

    /// The option order for a retry after the answer was revealed — see
    /// `advance(afterCorrectAnswer:)`. `nil` means the question's own order.
    private var retryOptions: [Domain.Selection]?

    /// How long feedback stays on screen at the least — all that's left when
    /// there's no spoken line to wait for, e.g. with sound switched off.
    private let minimumFeedbackTime: Duration

    // Explicitly empty, and it must stay. Removing it lets the compiler
    // synthesise the deinit, and Swift 6.3.3's SIL optimizer then crashes in
    // `EarlyPerfInliner` on that synthesised `deinit` when building with `-O`
    // (Release). Debug builds are unaffected, so this only shows up in a
    // release build. Re-test on a newer toolchain before deleting.
    deinit {}

    init(child: ChildProfile,
         domain: Domain,
         speechService: SpeechServicing,
         rewardService: RewardService,
         haptics: HapticsService,
         questionsPerRound: Int = 10,
         minimumFeedbackTime: Duration = .seconds(1.2)) {
        self.child = child
        self.domain = domain
        self.speechService = speechService
        self.rewardService = rewardService
        self.haptics = haptics
        self.questionsPerRound = questionsPerRound
        self.minimumFeedbackTime = minimumFeedbackTime
    }

    // MARK: - Lifecycle

    func onAppear() {
        haptics.prepare()
        if question == nil, !isRoundComplete {
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
        let isFirstTry = missesOnQuestion == 0

        // Only the first tap on a question counts toward mastery. A retry
        // comes after the child has been told — or shown — the answer, and
        // recording it as correct reset the miss streak, so a letter a child
        // always missed first time could never drop back a stage.
        if isFirstTry {
            domain.recordAnswer(child: child, question: question, correct: isCorrect)
        }

        let sentences: [String]
        if isCorrect {
            feedback = .correct
            // Same reasoning: the star is for knowing it, not for the retry.
            if isFirstTry {
                starsThisSession += 1
                starsThisRound += 1
                rewardService.awardStars(1, to: child)
            }
            haptics.success()
            sentences = domain.correctSpeech(for: question, isFirstTry: isFirstTry, childName: child.name)
        } else {
            missesOnQuestion += 1
            isAnswerRevealed = domain.revealsAnswer(afterMisses: missesOnQuestion)
            feedback = .incorrect(picked)
            haptics.gentleMiss()
            sentences = domain.incorrectSpeech(for: question, picked: selection, misses: missesOnQuestion)
        }

        advanceTask?.cancel()
        advanceTask = Task { [weak self, speechService, minimumFeedbackTime, isCorrect] in
            // Moves on once the line has actually been spoken, not after a
            // fixed guess — which either cut a long line off with the next
            // prompt or left a short one hanging.
            let started = ContinuousClock.now
            await speechService.speakAndWait(sentences)
            let elapsed = ContinuousClock.now - started
            try? await Task.sleep(for: max(minimumFeedbackTime - elapsed, .seconds(0.3)))
            guard !Task.isCancelled else { return }
            self?.advance(afterCorrectAnswer: isCorrect)
        }
    }

    /// The current question's options, or empty when there is nothing to ask.
    var options: [Domain.Selection] {
        retryOptions ?? question.map(domain.options(for:)) ?? []
    }

    /// The answer to the current question, for styling the revealed tile.
    var currentAnswer: Domain.Answer? {
        question.map(domain.answer(for:))
    }

    /// Maps what the child tapped to a comparable answer. Exposed so the view
    /// can style a tile without re-deriving the domain's mapping itself.
    func answer(for selection: Domain.Selection) -> Domain.Answer {
        domain.answer(for: selection)
    }

    func repeatPrompt() {
        // Not while feedback is playing: that line is what the child needs to
        // hear, and cutting it short would also end the feedback early.
        guard isAcceptingInput, let question else { return }
        speechService.speak(domain.promptSpeech(for: question))
    }

    /// Starts a fresh round from zero — the "Play again" action on the
    /// round-complete celebration.
    func startNewRound() {
        questionsAnswered = 0
        starsThisRound = 0
        isRoundComplete = false
        loadNextQuestion()
    }

    // MARK: - Flow

    private func advance(afterCorrectAnswer wasCorrect: Bool) {
        let wasRevealed = isAnswerRevealed
        feedback = .none
        isAnswerRevealed = false
        isAcceptingInput = true

        if wasCorrect {
            questionsAnswered += 1
            if questionsAnswered >= questionsPerRound {
                isRoundComplete = true
            } else {
                loadNextQuestion()
            }
        } else if wasRevealed {
            // A miss keeps the same question on screen, so getting it right
            // straight afterwards is the point — but the child has just watched
            // the right tile light up. Moving the tiles makes the retry a real
            // look at them rather than a tap on the spot that glowed.
            retryOptions = shufflingAnswerToNewSpot(options)
        }

        onSafeStoppingPoint?()
    }

    private func shufflingAnswerToNewSpot(_ options: [Domain.Selection]) -> [Domain.Selection] {
        let isAnswer: (Domain.Selection) -> Bool = { [domain, currentAnswer] in
            domain.answer(for: $0) == currentAnswer
        }
        var shuffled = options.shuffled()
        if shuffled.count > 1,
           let oldSpot = options.firstIndex(where: isAnswer),
           let newSpot = shuffled.firstIndex(where: isAnswer),
           newSpot == oldSpot {
            shuffled.swapAt(newSpot, (newSpot + 1) % shuffled.count)
        }
        return shuffled
    }

    private func loadNextQuestion() {
        let previous = question.map(domain.answer(for:))
        missesOnQuestion = 0
        retryOptions = nil
        question = domain.nextQuestion(for: child, excluding: previous)

        if let question {
            speechService.speak(domain.promptSpeech(for: question))
        }
    }
}

// MARK: - Letter quiz (spec F2)

/// The child hears a letter's name and finds it among the tiles, with the
/// letter's picture as a clue. The *word* stays unwritten until it's found:
/// shown up front, "Apple" in big type spelled the answer out as its own
/// first letter.
struct LetterQuizDomain: QuizDomain {
    typealias Question = QuizQuestion
    typealias Selection = Letter
    typealias Answer = String

    let progressService: ProgressService

    func answer(for question: QuizQuestion) -> String { question.answer.id }
    func answer(for selection: Letter) -> String { selection.id }
    func options(for question: QuizQuestion) -> [Letter] { question.options }

    func nextQuestion(for child: ChildProfile, excluding previous: String?) -> QuizQuestion? {
        progressService.makeQuestion(for: child, excluding: previous)
    }

    func recordAnswer(child: ChildProfile, question: QuizQuestion, correct: Bool) {
        progressService.record(child: child, letterID: question.answer.id, correct: correct)
    }

    func promptSpeech(for question: QuizQuestion) -> String {
        let letter = question.answer.uppercase
        let phrasings = [
            "Can you find the letter \(letter)?",
            "Where's the letter \(letter)?",
            "Find the letter \(letter)!",
            "Can you tap the letter \(letter)?",
            "Can you spot the letter \(letter)?"
        ]
        return phrasings.randomElement() ?? phrasings[0]
    }

    func correctSpeech(for question: QuizQuestion, isFirstTry: Bool, childName: String) -> [String] {
        let opener = isFirstTry ? QuizPraise.opener(childName: childName) : QuizPraise.retryOpener()
        var sentences = teachingLine(for: question)
        sentences[0] = "\(opener) \(sentences[0])"
        return sentences
    }

    /// First miss: names what they tapped and asks again, with nothing
    /// revealed, so the retry is still their own look. From the second miss:
    /// a clue, and the tile lights up (see `revealsAnswer`). Deliberately never
    /// says "wrong" — at this age a miss should redirect, not register as
    /// failure.
    ///
    /// Every sentence that ends on a lone letter is its own entry, so it's
    /// spoken with a gap after it — see `SpeechServicing.speakAndWait`.
    func incorrectSpeech(for question: QuizQuestion, picked: Letter, misses: Int) -> [String] {
        let target = question.answer.uppercase
        let tapped = picked.uppercase

        guard misses >= 2 else {
            let phrasings = [
                ["That's \(tapped)!", "Can you find \(target)?"],
                ["Good try! That's \(tapped).", "Where's \(target)?"],
                ["That one is \(tapped).", "Let's look for \(target)."],
                ["Almost! That's \(tapped).", "Find \(target)!"]
            ]
            return phrasings.randomElement() ?? phrasings[0]
        }

        return ["That's \(tapped).", "\(target) is for \(question.picture.word). Here it is!"]
    }

    func revealsAnswer(afterMisses misses: Int) -> Bool { misses >= 2 }

    /// Names the letter and its picture. Deliberately no letter *sound* ("B
    /// says buh"): the synthesized phonemes don't sound good enough yet to
    /// drop into the middle of a sentence.
    private func teachingLine(for question: QuizQuestion) -> [String] {
        let letter = question.answer.uppercase
        let word = question.picture.word
        let lines = [
            ["That's \(letter).", "\(letter) is for \(word)."],
            ["\(letter) is for \(word)!"],
            ["\(letter), like \(word)!"]
        ]
        return lines.randomElement() ?? lines[0]
    }
}

/// Openers for the correct-answer lines, shared by both quizzes. Several
/// rather than one fixed "Great job" — the exact same reply every time is what
/// reads as robotic.
private enum QuizPraise {

    static func opener(childName: String) -> String {
        let exclamations = [
            "Yes", "Great job", "Well done", "You got it", "Brilliant", "Woohoo",
            "Fantastic", "Amazing", "Super job", "Way to go", "You nailed it", "High five"
        ]
        let exclamation = exclamations.randomElement() ?? "Yes"
        // The name on every single line gets repetitive fast; about half is plenty.
        guard !childName.isEmpty, Bool.random() else { return exclamation + "!" }
        return "\(exclamation), \(childName)!"
    }

    /// For a correct retry after a miss: warm, but not the full celebration.
    static func retryOpener() -> String {
        ["That's it!", "There it is!", "You found it!"].randomElement() ?? "That's it!"
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

    /// Revealed once the letter is found — see `LetterQuizDomain`.
    var picture: LetterPicture? { question?.picture }

    /// "A is for Apple", shown with `picture`.
    var foundCaption: String {
        guard let question else { return "" }
        return "\(question.answer.uppercase) is for \(question.picture.word)"
    }
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

    /// A class, so its position carries across `nextQuestion` calls on this
    /// otherwise immutable domain value.
    private let objects = CountingObjectDeck()

    func answer(for question: NumberQuizQuestion) -> Int { question.answer.id }
    func answer(for selection: Int) -> Int { selection }
    func options(for question: NumberQuizQuestion) -> [Int] { question.options }

    func nextQuestion(for child: ChildProfile, excluding previous: Int?) -> NumberQuizQuestion? {
        progressService.makeNumberQuestion(for: child, excluding: previous, showing: objects.next())
    }

    func recordAnswer(child: ChildProfile, question: NumberQuizQuestion, correct: Bool) {
        progressService.record(child: child, numberID: question.answer.id, correct: correct)
    }

    func promptSpeech(for question: NumberQuizQuestion) -> String {
        "How many \(question.object.plural) do you see?"
    }

    func correctSpeech(for question: NumberQuizQuestion, isFirstTry: Bool, childName: String) -> [String] {
        let opener = isFirstTry ? QuizPraise.opener(childName: childName) : QuizPraise.retryOpener()
        let things = question.object.name(forCount: question.answer.id)
        return ["\(opener) \(question.answer.name) \(things)!"]
    }

    /// Says the count *with* the object — "There are four dogs" — so the
    /// correction models counting a quantity rather than just naming a numeral.
    func incorrectSpeech(for question: NumberQuizQuestion, picked: Int, misses: Int) -> [String] {
        let count = question.answer.id
        let verb = count == 1 ? "is" : "are"
        let things = question.object.name(forCount: count)
        return ["There \(verb) \(question.answer.name.lowercased()) \(things). Let's try again."]
    }

    /// The miss line already says the count aloud, so the tile lights up with it.
    func revealsAnswer(afterMisses misses: Int) -> Bool { true }
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

    var promptEmoji: String { question?.object.emoji ?? "❓" }
    var promptCount: Int { question?.answer.id ?? 0 }

    /// The on-screen twin of the spoken prompt, so it names the object too.
    var promptText: String {
        question.map(domain.promptSpeech(for:)) ?? "How many do you see?"
    }
}
