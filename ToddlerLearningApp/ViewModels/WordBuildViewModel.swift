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
//  a clean word: at most `missesAllowedForStar` wrong taps, and no letter that
//  needed showing. A child who's stuck on a letter gets it shown after
//  `missesBeforeReveal` wrong taps, so they can always finish.
//
//  How hard it is follows the child — see `WordBuildProgression` — and the
//  level is saved per child, so they pick up where they left off. Beyond that
//  this activity keeps no persisted mastery tracking of its own: it reinforces
//  letters the child is already building via Learn/Quiz rather than
//  introducing a third thing for the parent dashboard to report on.
//

import Foundation

/// How hard Build the Word is right now: how long the word is and how many
/// wrong-letter tiles come with it. Moves up after a run of clean words and
/// back down after a couple of struggles, so it follows the child rather
/// than a fixed schedule. The level is saved per child
/// (`ChildProfile.wordBuildLevel`); the runs toward the next one start fresh
/// each visit.
struct WordBuildProgression {

    struct Level: Equatable {
        let wordLength: Int
        let distractors: Int

        /// How many of the distractors may be shaped like the word's own
        /// letters (B beside D) — the hardest kind to rule out.
        let lookAlikes: Int
    }

    static let levels = [
        Level(wordLength: 3, distractors: 2, lookAlikes: 1),
        Level(wordLength: 3, distractors: 4, lookAlikes: 2),
        Level(wordLength: 4, distractors: 4, lookAlikes: 2)
    ]

    /// Clean words in a row that move up a level.
    static let cleanRunToLevelUp = 3

    /// Words in a row without a star that move back down one.
    static let missRunToLevelDown = 2

    private(set) var levelIndex: Int
    private var cleanRun = 0
    private var missRun = 0

    init(levelIndex: Int = 0) {
        self.levelIndex = min(max(levelIndex, 0), Self.levels.count - 1)
    }

    var level: Level { Self.levels[levelIndex] }

    mutating func record(clean: Bool) {
        if clean {
            cleanRun += 1
            missRun = 0
        } else {
            missRun += 1
            cleanRun = 0
        }

        if cleanRun >= Self.cleanRunToLevelUp, levelIndex < Self.levels.count - 1 {
            levelIndex += 1
            cleanRun = 0
        } else if missRun >= Self.missRunToLevelDown, levelIndex > 0 {
            levelIndex -= 1
            missRun = 0
        }
    }
}

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

    /// Wrong taps a word can take and still earn its star.
    static let missesAllowedForStar = 2

    /// Wrong taps on one letter before its tile is shown.
    static let missesBeforeReveal = 2

    /// Words to solve per round (spec F27) — a finish line rather than the
    /// activity running forever until the child backs out.
    let wordsPerRound: Int

    private(set) var currentWord: WordItem
    private(set) var scrambledLetters: [ScrambledLetter] = []
    private(set) var filledLetters: [String?] = []
    private(set) var isComplete = false
    private(set) var starsThisSession = 0

    /// Stars earned in the current round, for the round-complete screen.
    /// Not `wordsCompleted`: a word that wasn't clean earns none.
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
    var isPromptPlaying: Bool { promptPlayback.isPlaying }

    private(set) var missesThisWord = 0

    /// The tile lit up once a letter has had `missesBeforeReveal` wrong taps —
    /// the right one, so a child who's stuck can still finish. Cleared when
    /// that letter is placed.
    private(set) var revealedTileID: UUID?

    /// Whether any letter of this word needed showing. The word still
    /// finishes, but it isn't clean, so it earns no star.
    private(set) var neededHelp = false

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
    private let progressService: ProgressService
    private let haptics: HapticsService
    private let words: [WordItem]
    private var progression: WordBuildProgression

    /// The shortest a wrong tap locks the tiles for — all that's left when
    /// there's no spoken line to wait for, e.g. with sound switched off.
    private let minimumLockTime: Duration

    private var missesOnSlot = 0
    private var pendingTask: Task<Void, Never>?
    private var lockTask: Task<Void, Never>?

    private let promptPlayback = PlaybackTracker()

    init(child: ChildProfile,
         speechService: SpeechServicing,
         rewardService: RewardService,
         progressService: ProgressService,
         haptics: HapticsService,
         wordsPerRound: Int = 5,
         words: [WordItem]? = nil,
         startingLevel: Int? = nil,
         minimumLockTime: Duration = .seconds(1)) {
        self.child = child
        self.speechService = speechService
        self.rewardService = rewardService
        self.progressService = progressService
        self.haptics = haptics
        self.wordsPerRound = wordsPerRound
        // Optional rather than defaulting to `WordBuildContent.words`: a default
        // argument is evaluated outside the main actor that list belongs to.
        self.words = words ?? WordBuildContent.words
        self.minimumLockTime = minimumLockTime
        // The child's saved level unless a caller overrides it.
        let progression = WordBuildProgression(levelIndex: startingLevel ?? child.wordBuildLevel)
        self.progression = progression
        self.currentWord = Self.pickWord(from: self.words, for: progression.level, excluding: nil)
        setUp(for: currentWord)
    }

    var promptEmoji: String { currentWord.emoji }

    var level: WordBuildProgression.Level { progression.level }

    /// The slot the next correct letter goes in — outlined on screen, and
    /// what the spoken question is about.
    var nextSlotIndex: Int? { filledLetters.firstIndex(where: { $0 == nil }) }

    private var spokenWord: String { currentWord.id.capitalized }

    // MARK: - Lifecycle

    func onAppear() {
        haptics.prepare()
        ask([spellPrompt, slotQuestion(for: 0)])
    }

    /// "Let's spell Cat!"
    private var spellPrompt: SpokenLine {
        SpokenLine(clip: Clip.wordSpell(currentWord.id), text: "Let's spell \(spokenWord)!")
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
        missesOnSlot = 0
        revealedTileID = nil
        haptics.tap()

        // A bare single-character utterance makes AVSpeechSynthesizer spell it
        // out with "capital" prefixed to disambiguate case — the trailing
        // period keeps it read as just the letter name (same fix as
        // SpeechService.teachLetter).
        if let next = nextSlotIndex {
            ask([Self.letterName(expectedLetter), slotQuestion(for: next)])
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
        ask([wordAlone, slotQuestion(for: slot)])
    }

    /// "Cat!" — the word on its own.
    private var wordAlone: SpokenLine {
        SpokenLine(clip: Clip.wordAlone(currentWord.id), text: "\(spokenWord)!")
    }

    /// A letter named on its own, as its tile is placed. The trailing period
    /// is what stops AVSpeechSynthesizer spelling a lone character out with
    /// "capital" prefixed (same fix as `SpeechService.teachLetter`); the
    /// recording just says the letter.
    private static func letterName(_ letter: String) -> SpokenLine {
        SpokenLine(clip: Clip.letterName(letter), text: "\(letter).")
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
    /// After `missesBeforeReveal` on one letter, the right tile lights up
    /// instead. Deliberately never says "wrong" — a miss should redirect, not
    /// register as failure.
    ///
    /// Letters are named with `Spoken.letter` — see why there.
    private func reject(at index: Int, expected: String) {
        let tapped = scrambledLetters[index].letter
        scrambledLetters[index].isRejected = true
        scrambledLetters[index].shakes += 1
        missesThisWord += 1
        missesOnSlot += 1
        haptics.gentleMiss()

        let thats = SpokenLine(clip: Clip.letterThats(tapped), text: "That's \(Spoken.letter(tapped)).")
        var sentences = [
            thats,
            SpokenLine(clip: Clip.letterWeNeed(expected), text: "We need \(Spoken.letter(expected))!")
        ]
        if missesOnSlot >= Self.missesBeforeReveal,
           revealedTileID == nil,
           let answer = scrambledLetters.first(where: { $0.letter == expected && !$0.isUsed }) {
            revealedTileID = answer.id
            neededHelp = true
            sentences = [
                thats,
                SpokenLine(clip: Clip.letterHeres(expected), text: "Here's \(Spoken.letter(expected))!")
            ]
        }

        isLocked = true
        lockTask?.cancel()
        lockTask = Task { [weak self, speechService, minimumLockTime] in
            let started = ContinuousClock.now
            await speechService.speakAndWait(sentences)
            let elapsed = ContinuousClock.now - started
            try? await Task.sleep(for: max(minimumLockTime - elapsed, .zero))
            guard !Task.isCancelled else { return }
            self?.isLocked = false
        }
    }

    private func complete(lastLetter: String) {
        isComplete = true
        didEarnStar = missesThisWord <= Self.missesAllowedForStar && !neededHelp
        if didEarnStar {
            starsThisSession += 1
            starsThisRound += 1
            rewardService.awardStars(1, to: child)
        }
        progression.record(clean: didEarnStar)
        progressService.recordWordBuildLevel(progression.levelIndex, for: child)
        haptics.success()

        // Varied praise for a clean word, same as the quizzes; a word that
        // wasn't clean still finishes warmly, just without the celebration.
        let closing = didEarnStar
            ? Praise.opener(childName: child.name)
            : SpokenLine(clip: Clip.wordYouDidIt, text: "You did it!")
        let sentences = [Self.letterName(lastLetter), wordAlone, closing]

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
        let candidate = Self.pickWord(from: words, for: progression.level, excluding: currentWord.id)
        currentWord = candidate
        setUp(for: candidate)
        isComplete = false
        didEarnStar = false
        onSafeStoppingPoint?()
        ask([spellPrompt, slotQuestion(for: 0)])
    }

    private func setUp(for word: WordItem) {
        missesThisWord = 0
        missesOnSlot = 0
        revealedTileID = nil
        neededHelp = false
        let tiles = word.letters + Self.distractors(for: word, level: progression.level)
        scrambledLetters = tiles.map { ScrambledLetter(letter: $0) }.shuffled()
        filledLetters = Array(repeating: nil, count: word.letters.count)
    }

    /// A word of the level's length, not the one just played. Falls back to
    /// any word if the list has none of that length.
    private static func pickWord(from words: [WordItem],
                                 for level: WordBuildProgression.Level,
                                 excluding previous: String?) -> WordItem {
        let ofLength = words.filter { $0.letters.count == level.wordLength }
        let pool = ofLength.isEmpty ? words : ofLength
        return pool.filter { $0.id != previous }.randomElement()
            ?? pool.first
            ?? WordBuildContent.words[0]
    }

    /// Letters that aren't in the word: up to `level.lookAlikes` shaped like
    /// its own letters (B beside D), so telling them apart matters, and the
    /// rest any other letter.
    static func distractors(for word: WordItem, level: WordBuildProgression.Level) -> [String] {
        let inWord = Set(word.letters)
        let lookAlikes = Set(word.letters.flatMap { AlphabetContent.lookAlikes(of: $0) })
            .subtracting(inWord)
        let others = Set(AlphabetContent.letters.map(\.id))
            .subtracting(inWord)
            .subtracting(lookAlikes)

        let chosenLookAlikes = Array(lookAlikes.shuffled().prefix(min(level.lookAlikes, level.distractors)))
        return chosenLookAlikes + others.shuffled().prefix(level.distractors - chosenLookAlikes.count)
    }

    /// What the child is asked about the slot they're filling — a real
    /// decision about one position, rather than hunting for any tile that
    /// happens to fit.
    private func slotQuestion(for slot: Int) -> SpokenLine {
        if slot == 0 {
            // Not "What does Cat start with?" — the voice swallows "does" into
            // something that hears as "is". Keep this in step with
            // tools/gen_phase_b.py, which records the same words.
            return SpokenLine(clip: Clip.wordStartsWith(currentWord.id),
                              text: "What's the first letter in \(spokenWord)?")
        }
        if slot == currentWord.letters.count - 1 {
            return SpokenLine(clip: Clip.wordLastLetter, text: "What's the last letter?")
        }
        return SpokenLine(clip: Clip.wordNext, text: "What comes next?")
    }

    /// Fire-and-forget: a newer line cuts this one off, same as `speak`.
    private func say(_ sentences: [SpokenLine]) {
        Task { [speechService] in
            await speechService.speakAndWait(sentences)
        }
    }

    /// Like `say`, for a line that asks the question — tracked, so a replay
    /// tap can tell it's still playing. See `isPromptPlaying`.
    private func ask(_ sentences: [SpokenLine]) {
        // Returns when the line finishes or something newer cuts it off — a
        // wrong tap's line, say — either way it's no longer playing.
        promptPlayback.start { [speechService] in
            await speechService.speakAndWait(sentences)
        }
    }
}
