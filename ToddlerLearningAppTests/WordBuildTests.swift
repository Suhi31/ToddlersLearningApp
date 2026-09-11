//
//  WordBuildTests.swift
//  ToddlerLearningAppTests
//
//  Build the Word only teaches spelling if tapping at random doesn't work:
//  these pin the extra tiles, the cost of a wrong tap, and the star rule.
//

import Foundation
import SwiftData
import Testing

@testable import ToddlerLearningApp

@MainActor
struct WordBuildTests {

    private static let dog = WordItem(id: "DOG", emoji: "🐶", colorIndex: 1)

    // MARK: - Fixture

    /// `speech` is optional rather than defaulting to `SilentSpeech()`: a
    /// default argument is evaluated outside the main actor that type needs.
    private static func makeGame(speech: SpeechServicing? = nil) throws -> (WordBuildViewModel, ChildProfile) {
        let container = try ModelContainer(
            for: ChildProfile.self, LetterProgress.self, NumberProgress.self, TraceProgress.self, SessionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // Not `container.mainContext` — see `ProgressServiceTests.makeService`.
        let context = ModelContext(container)
        let child = ChildProfile(name: "Test", age: 4, avatarEmoji: "🐰")
        context.insert(child)
        let game = WordBuildViewModel(child: child,
                                      speechService: speech ?? SilentSpeech(),
                                      rewardService: RewardService(context: context),
                                      haptics: HapticsService(),
                                      words: [dog],
                                      minimumLockTime: .zero)
        return (game, child)
    }

    private static func tile(_ letter: String, in game: WordBuildViewModel) throws -> WordBuildViewModel.ScrambledLetter {
        try #require(game.scrambledLetters.first { $0.letter == letter && !$0.isUsed })
    }

    private static func extras(in game: WordBuildViewModel) -> [WordBuildViewModel.ScrambledLetter] {
        game.scrambledLetters.filter { !dog.letters.contains($0.letter) }
    }

    /// The lock lifts on a short timer even with nothing spoken.
    private static func waitForUnlock(_ game: WordBuildViewModel) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while game.isLocked {
            guard ContinuousClock.now < deadline else {
                Issue.record("The tiles never unlocked")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func spell(_ game: WordBuildViewModel) throws {
        for letter in dog.letters {
            game.tapScrambled(try tile(letter, in: game))
        }
    }

    // MARK: - Tiles

    @Test("The tiles mix in three letters that aren't in the word, two of them look-alikes")
    func tilesIncludeDistractors() throws {
        let (game, _) = try Self.makeGame()
        let letters = game.scrambledLetters.map(\.letter)
        let extras = Self.extras(in: game).map(\.letter)

        #expect(letters.count == 6)
        #expect(Set(letters).count == 6)
        #expect(extras.count == 3)
        // The look-alikes of D, O and G that aren't in DOG are B, C and Q.
        #expect(extras.filter { ["B", "C", "Q"].contains($0) }.count == 2)
    }

    // MARK: - Wrong taps

    @Test("A wrong tap locks the tiles and greys that one out until its slot is filled")
    func wrongTapLocksAndGreysOut() async throws {
        let (game, _) = try Self.makeGame()

        // O is in the word, just not first.
        let early = try Self.tile("O", in: game)
        game.tapScrambled(early)
        #expect(game.isLocked)
        #expect(game.missesThisWord == 1)
        #expect(game.scrambledLetters.first { $0.id == early.id }?.isRejected == true)

        // Ignored while locked — even the right letter.
        game.tapScrambled(try Self.tile("D", in: game))
        #expect(game.filledLetters[0] == nil)

        try await Self.waitForUnlock(game)
        game.tapScrambled(try Self.tile("D", in: game))
        #expect(game.filledLetters[0] == "D")
        #expect(game.nextSlotIndex == 1)

        // Wrong for the first slot, not for good: it's the next letter.
        #expect(game.scrambledLetters.first { $0.id == early.id }?.isRejected == false)
        game.tapScrambled(try Self.tile("O", in: game))
        #expect(game.filledLetters[1] == "O")
    }

    // MARK: - Replay

    @Test("Tapping the picture does nothing while the question is still being spoken")
    func replayWaitsForQuestionToFinish() async throws {
        let speech = HeldSpeech()
        let (game, _) = try Self.makeGame(speech: speech)
        game.onAppear()
        try await waitUntil { speech.lines.count == 1 }
        #expect(game.isPromptPlaying)

        game.repeatPrompt()
        game.repeatPrompt()
        await Task.yield()
        #expect(speech.lines.count == 1, "Replays mid-question must not restart it")

        speech.finishAll()
        try await waitUntil { !game.isPromptPlaying }
        game.repeatPrompt()
        try await waitUntil { speech.lines.count == 2 }
    }

    // MARK: - Stars

    @Test("A word spelled cleanly earns a star")
    func cleanSpellingEarnsStar() throws {
        let (game, child) = try Self.makeGame()

        try Self.spell(game)

        #expect(game.isComplete)
        #expect(game.didEarnStar)
        #expect(child.starCount == 1)
        #expect(game.starsThisRound == 1)
    }

    @Test("More than two misses finishes the word without a star")
    func tooManyMissesEarnsNoStar() async throws {
        let (game, child) = try Self.makeGame()

        for extra in Self.extras(in: game) {
            game.tapScrambled(extra)
            try await Self.waitForUnlock(game)
        }
        #expect(game.missesThisWord == 3)

        try Self.spell(game)

        #expect(game.isComplete)
        #expect(!game.didEarnStar)
        #expect(child.starCount == 0)
        #expect(game.starsThisRound == 0)
        #expect(game.wordsCompleted == 1)
    }
}

@MainActor
private final class SilentSpeech: SpeechServicing {
    func speak(_ text: String) {}
    func speakAndWait(_ sentences: [String]) async {}
    func teachLetter(_ letter: Letter) async {}
    func teachNumber(_ number: NumberItem) async {}
    func stop() {}
}
