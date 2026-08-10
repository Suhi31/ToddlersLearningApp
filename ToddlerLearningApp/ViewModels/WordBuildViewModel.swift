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
    }

    private(set) var currentWord: WordItem
    private(set) var scrambledLetters: [ScrambledLetter] = []
    private(set) var filledLetters: [String?] = []
    private(set) var isComplete = false
    private(set) var starsThisSession = 0

    /// Same safe-stopping-point pattern as the other activity screens (spec F5).
    var onSafeStoppingPoint: (() -> Void)?

    let child: ChildProfile
    private let speechService: SpeechServicing
    private let rewardService: RewardService
    private let haptics: HapticsService

    private var pendingTask: Task<Void, Never>?

    init(child: ChildProfile,
         speechService: SpeechServicing,
         rewardService: RewardService,
         haptics: HapticsService) {
        self.child = child
        self.speechService = speechService
        self.rewardService = rewardService
        self.haptics = haptics
        self.currentWord = WordBuildContent.words.randomElement() ?? WordBuildContent.words[0]
        setUp(for: currentWord)
    }

    var promptEmoji: String { currentWord.emoji }

    // MARK: - Lifecycle

    func onAppear() {
        haptics.prepare()
        speechService.speak("Can you spell \(currentWord.id.capitalized)?")
    }

    func onDisappear() {
        pendingTask?.cancel()
        speechService.stop()
    }

    // MARK: - Intent

    func tapScrambled(_ tapped: ScrambledLetter) {
        guard !isComplete,
              let index = scrambledLetters.firstIndex(where: { $0.id == tapped.id }),
              !scrambledLetters[index].isUsed,
              let nextSlotIndex = filledLetters.firstIndex(where: { $0 == nil })
        else { return }

        let expectedLetter = currentWord.letters[nextSlotIndex]
        guard scrambledLetters[index].letter == expectedLetter else {
            // Wrong letter for this slot — a gentle nudge, not a marked error;
            // the tile stays available to try again.
            haptics.gentleMiss()
            return
        }

        scrambledLetters[index].isUsed = true
        filledLetters[nextSlotIndex] = expectedLetter
        haptics.tap()
        // A bare single-character utterance makes AVSpeechSynthesizer spell it
        // out with "capital" prefixed to disambiguate case — the trailing
        // period keeps it read as just the letter name (same fix as
        // SpeechService.teachLetter).
        speechService.speak("\(expectedLetter).")

        if !filledLetters.contains(nil) {
            complete()
        }
    }

    // MARK: - Flow

    private func complete() {
        isComplete = true
        starsThisSession += 1
        rewardService.awardStars(1, to: child)
        haptics.success()
        speechService.speak("\(currentWord.id.capitalized)! Great job!")

        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            self?.nextWord()
        }
    }

    private func nextWord() {
        let previous = currentWord.id
        var candidate = WordBuildContent.words.randomElement() ?? WordBuildContent.words[0]
        while candidate.id == previous, WordBuildContent.words.count > 1 {
            candidate = WordBuildContent.words.randomElement() ?? WordBuildContent.words[0]
        }

        currentWord = candidate
        setUp(for: candidate)
        isComplete = false
        onSafeStoppingPoint?()

        pendingTask?.cancel()
        pendingTask = Task { [speechService] in
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            speechService.speak("Can you spell \(candidate.id.capitalized)?")
        }
    }

    private func setUp(for word: WordItem) {
        scrambledLetters = word.letters.map { ScrambledLetter(letter: $0) }.shuffled()
        filledLetters = Array(repeating: nil, count: word.letters.count)
    }
}
