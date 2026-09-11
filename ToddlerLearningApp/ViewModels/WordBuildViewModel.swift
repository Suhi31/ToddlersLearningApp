//
//  WordBuildViewModel.swift
//  ToddlerLearningApp
//
//  Endless-Alphabet-style blending: hear the word, tap its letters in order
//  from a scrambled pool to spell it. Deliberately tap-in-sequence rather
//  than drag-and-drop — precise dragging is a harder motor skill than
//  tapping a large tile, and this game is about sound-to-letter transfer,
//  not fine motor control (that's what Phase D's tracing is for).
//
//  Built so guessing doesn't pay. The pool used to be exactly the word's own
//  letters and a wrong tap cost nothing, so tapping at random always spelled
//  the word within a few taps — the last letter for free. Now the pool mixes
//  in letters that aren't in the word, a wrong tap locks the tiles while the
//  voice names what was tapped and what's needed, and the star only comes for
//  a word spelled with at most `missesAllowedForStar` wrong taps.
//
//  Session-only: this activity has no persisted mastery tracking of its own.
//  It reinforces letters the child is already building via Learn/Quiz rather
//  than introducing a third thing for the parent dashboard to report on.
//

import Foundation

@MainActor
@Observable
final class WordBuildViewModel {

    struct ScrambledLetter: Identifiable, Hashable {
        let id = UUID()
        let letter: String
        var isUsed = false

        /// Tapped, and wrong for the slot being filled now. Cleared once that
        /// slot fills: a letter from later in the word is wrong *now*, not
        /// for good.
        var isRejected = false

        /// Bumped on every wrong tap, to replay the tile's shake.
        var shakes = 0
    }

    /// Letters mixed into the pool that aren't in the word.
    static let distractorCount = 3

    /// Wrong taps a word can take and still earn its star.
    static let missesAllowedForStar = 2

    /// Words to solve per round (spec F27) — a finish line rather than the
    /// activity running forever until the child backs out.
    let wordsPerRound: Int

    private(set) var currentWord: WordItem
    private(set) var scrambledLetters: [ScrambledLetter] = []
    private(set) var filledLetters: [String?] = []
    private(set) var isComplete = false
    private(set) var starsThisSession = 0

    /// Stars earned in the current round, for the round-complete screen.
    /// Not `wordsCompleted`: a word finished with too many misses earns none.
    private(set) var starsThisRound = 0

    /// Whether the word just finished earned its star — drives the star burst.
    private(set) var didEarnStar = false

    /// Set by a wrong tap until the voice has said what was tapped and what's
    /// needed. This is what stops mashing: a wrong tap now costs time.
    private(set) var isLocked = false

    /// Whether a line asking the question is being spoken right now — the
    /// word's opening prompt, the question after each correct letter, or a
    /// replay. A picture tap while it is does nothing: restarting the same
    /// line from the top on every tap only makes it stutter.
    private(set) var isPromptPlaying = false

    private(set) var missesThisWord = 0

    /// Words solved so far in the current round.
    private(set) var wordsCompleted = 0

    /// Set once `wordsCompleted` reaches `wordsPerRound`. The view shows a
    /// celebration instead of the next word; `startNewRound()` clears it.
    private(set) var isRoundComplete = false

    /// Same safe-stopping-point pattern as the other activity screens (spec F5).
    var onSafeStoppingPoint: (() -> Void)?

    let child: ChildProfile
    private let speechService: SpeechServicing
    private let rewardService: RewardService
    private let haptics: HapticsService
    private let words: [WordItem]

    /// The shortest a wrong tap locks the tiles for — all that's left when
    /// there's no spoken line to wait for, e.g. with sound switched off.
    private let minimumLockTime: Duration

    private var pendingTask: Task<Void, Never>?
    private var lockTask: Task<Void, Never>?

    /// Numbers each question playback — see `ask(_:)`.
    private var promptPlayback = 0

    init(child: ChildProfile,
         speechService: SpeechServicing,
         rewardService: RewardService,
         haptics: HapticsService,
         wordsPerRound: Int = 5,
         words: [WordItem] = WordBuildContent.words,
         minimumLockTime: Duration = .seconds(1)) {
        self.child = child
        self.speechService = speechService
        self.rewardService = rewardService
        self.haptics = haptics
        self.wordsPerRound = wordsPerRound
        self.words = words
        self.minimumLockTime = minimumLockTime
        self.currentWord = words.randomElement() ?? WordBuildContent.words[0]
        setUp(for: currentWord)
    }

    var promptEmoji: String { currentWord.emoji }

    /// The slot the next correct letter goes in — outlined on screen, and
    /// what the spoken question is about.
    var nextSlotIndex: Int? { filledLetters.firstIndex(where: { $0 == nil }) }

    private var spokenWord: String { currentWord.id.capitalized }

    // MARK: - Lifecycle

    func onAppear() {
        haptics.prepare()
        ask(["Let's spell \(spokenWord)!", slotQuestion(for: 0)])
    }

    func onDisappear() {
        pendingTask?.cancel()
        lockTask?.cancel()
        isLocked = false
        speechService.stop()
    }

    // MARK: - Intent

    func tapScrambled(_ tapped: ScrambledLetter) {
        guard !isComplete, !isLocked,
              let index = scrambledLetters.firstIndex(where: { $0.id == tapped.id }),
              !scrambledLetters[index].isUsed,
              !scrambledLetters[index].isRejected,
              let slot = nextSlotIndex
        else { return }

        let expectedLetter = currentWord.letters[slot]
        guard scrambledLetters[index].letter == expectedLetter else {
            reject(at: index, expected: expectedLetter)
            return
        }

        scrambledLetters[index].isUsed = true
        filledLetters[slot] = expectedLetter
        for other in scrambledLetters.indices {
            scrambledLetters[other].isRejected = false
        }
        haptics.tap()

        // A bare single-character utterance makes AVSpeechSynthesizer spell it
        // out with "capital" prefixed to disambiguate case — the trailing
        // period keeps it read as just the letter name (same fix as
        // SpeechService.teachLetter).
        if let next = nextSlotIndex {
            ask(["\(expectedLetter).", slotQuestion(for: next)])
        } else {
            complete(lastLetter: expectedLetter)
        }
    }

    /// Says the word and the current question again — the picture's tap.
    /// Not while the tiles are locked (that line is still playing), while the
    /// question is still being spoken (see `isPromptPlaying`), or once the
    /// word is done.
    func repeatPrompt() {
        guard !isComplete, !isLocked, !isPromptPlaying, let slot = nextSlotIndex else { return }
        ask(["\(spokenWord)!", slotQuestion(for: slot)])
    }

    /// Starts a fresh round from zero — the "Play again" action on the
    /// round-complete celebration.
    func startNewRound() {
        wordsCompleted = 0
        starsThisRound = 0
        isRoundComplete = false
        nextWord()
    }

    // MARK: - Flow

    /// A wrong tap: the tile shakes and greys out for this slot, and every
    /// tile locks while the voice names what was tapped and what's needed.
    /// Deliberately never says "wrong" — a miss should redirect, not register
    /// as failure.
    ///
    /// Always "the letter A", never a bare "A" mid-sentence: the voice reads a
    /// lone A as the word "a" ("uh"), and E comes out just as unclear.
    private func reject(at index: Int, expected: String) {
        let tapped = scrambledLetters[index].letter
        scrambledLetters[index].isRejected = true
        scrambledLetters[index].shakes += 1
        missesThisWord += 1
        haptics.gentleMiss()

        isLocked = true
        lockTask?.cancel()
        lockTask = Task { [weak self, speechService, minimumLockTime] in
            let started = ContinuousClock.now
            await speechService.speakAndWait(["That's the letter \(tapped).", "We need the letter \(expected)!"])
            let elapsed = ContinuousClock.now - started
            try? await Task.sleep(for: max(minimumLockTime - elapsed, .zero))
            guard !Task.isCancelled else { return }
            self?.isLocked = false
        }
    }

    private func complete(lastLetter: String) {
        isComplete = true
        didEarnStar = missesThisWord <= Self.missesAllowedForStar
        if didEarnStar {
            starsThisSession += 1
            starsThisRound += 1
            rewardService.awardStars(1, to: child)
        }
        haptics.success()

        let sentences = ["\(lastLetter).", "\(spokenWord)!", didEarnStar ? "Great job!" : "You did it!"]

        wordsCompleted += 1
        guard wordsCompleted < wordsPerRound else {
            isRoundComplete = true
            say(sentences)
            onSafeStoppingPoint?()
            return
        }

        pendingTask?.cancel()
        pendingTask = Task { [weak self, speechService] in
            // Moves on once the line has been heard, rather than after a fixed
            // delay the next word's prompt could cut it off at.
            await speechService.speakAndWait(sentences)
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            self?.nextWord()
        }
    }

    private func nextWord() {
        let previous = currentWord.id
        var candidate = words.randomElement() ?? WordBuildContent.words[0]
        while candidate.id == previous, words.count > 1 {
            candidate = words.randomElement() ?? WordBuildContent.words[0]
        }

        currentWord = candidate
        setUp(for: candidate)
        isComplete = false
        didEarnStar = false
        onSafeStoppingPoint?()
        ask(["Let's spell \(spokenWord)!", slotQuestion(for: 0)])
    }

    private func setUp(for word: WordItem) {
        missesThisWord = 0
        let tiles = word.letters + Self.distractors(for: word)
        scrambledLetters = tiles.map { ScrambledLetter(letter: $0) }.shuffled()
        filledLetters = Array(repeating: nil, count: word.letters.count)
    }

    /// Letters that aren't in the word: up to two shaped like its own letters
    /// (B beside D), so telling them apart matters, and the rest any other
    /// letter.
    static func distractors(for word: WordItem) -> [String] {
        let inWord = Set(word.letters)
        let lookAlikes = Set(word.letters.flatMap { AlphabetContent.lookAlikes(of: $0) })
            .subtracting(inWord)
        let others = Set(AlphabetContent.letters.map(\.id))
            .subtracting(inWord)
            .subtracting(lookAlikes)

        let chosenLookAlikes = Array(lookAlikes.shuffled().prefix(2))
        return chosenLookAlikes + others.shuffled().prefix(distractorCount - chosenLookAlikes.count)
    }

    /// What the child is asked about the slot they're filling — a real
    /// decision about one position, rather than hunting for any tile that
    /// happens to fit.
    private func slotQuestion(for slot: Int) -> String {
        if slot == 0 { return "What does \(spokenWord) start with?" }
        if slot == currentWord.letters.count - 1 { return "What's the last letter?" }
        return "What comes next?"
    }

    /// Fire-and-forget: a newer line cuts this one off, same as `speak`.
    private func say(_ sentences: [String]) {
        Task { [speechService] in
            await speechService.speakAndWait(sentences)
        }
    }

    /// Like `say`, for a line that asks the question — tracked, so a replay
    /// tap can tell it's still playing. Numbered, so an older line finishing
    /// late (cut off by this one) can't clear `isPromptPlaying` for it.
    private func ask(_ sentences: [String]) {
        promptPlayback += 1
        let playback = promptPlayback
        isPromptPlaying = true

        Task { [weak self, speechService] in
            // Returns when the line finishes or something newer cuts it off —
            // a wrong tap's line, say — either way it's no longer playing.
            await speechService.speakAndWait(sentences)
            guard let self, self.promptPlayback == playback else { return }
            self.isPromptPlaying = false
        }
    }
}
