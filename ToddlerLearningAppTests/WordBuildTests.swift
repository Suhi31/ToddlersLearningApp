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
    private static func makeGame(speech: SpeechServicing? = nil,
                                 words: [WordItem]? = nil,
                                 startingLevel: Int? = nil,
                                 savedLevel: Int = 0) throws -> (WordBuildViewModel, ChildProfile) {
        let container = try ModelContainer(
            for: ChildProfile.self, LetterProgress.self, NumberProgress.self, TraceProgress.self, SessionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // Not `container.mainContext` — see `ProgressServiceTests.makeService`.
        let context = ModelContext(container)
        let child = ChildProfile(name: "Test", age: 4, avatarEmoji: "🐰")
        child.wordBuildLevel = savedLevel
        context.insert(child)
        let game = WordBuildViewModel(child: child,
                                      speechService: speech ?? SilentSpeech(),
                                      rewardService: RewardService(context: context),
                                      progressService: ProgressService(context: context),
                                      haptics: HapticsService(),
                                      words: words ?? [dog],
                                      startingLevel: startingLevel,
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

    @Test("The first level mixes in two letters that aren't in the word, one a look-alike")
    func tilesIncludeDistractors() throws {
        let (game, _) = try Self.makeGame()
        let letters = game.scrambledLetters.map(\.letter)
        let extras = Self.extras(in: game).map(\.letter)

        #expect(letters.count == 5)
        #expect(Set(letters).count == 5)
        #expect(extras.count == 2)
        // The look-alikes of D, O and G that aren't in DOG are B, C and Q.
        #expect(extras.filter { ["B", "C", "Q"].contains($0) }.count == 1)
    }

    @Test("Higher levels add more wrong-letter tiles, then four-letter words")
    func higherLevelsAreHarder() throws {
        let (second, _) = try Self.makeGame(startingLevel: 1)
        #expect(second.scrambledLetters.count == 7)
        #expect(Self.extras(in: second).filter { ["B", "C", "Q"].contains($0.letter) }.count == 2)

        let frog = WordItem(id: "FROG", emoji: "🐸", colorIndex: 0)
        let (third, _) = try Self.makeGame(words: [Self.dog, frog], startingLevel: 2)
        #expect(third.currentWord == frog)
        #expect(third.scrambledLetters.count == 8)
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

    /// One miss on each letter — three in all, none of them enough on its
    /// own to show the tile, so this is the total-misses rule alone.
    @Test("More than two misses finishes the word without a star")
    func tooManyMissesEarnsNoStar() async throws {
        let (game, child) = try Self.makeGame()
        let wrongFor = ["D": "O", "O": "G", "G": "D"]

        for letter in Self.dog.letters {
            let wrong = try #require(wrongFor[letter])
            if let tile = game.scrambledLetters.first(where: { $0.letter == wrong && !$0.isUsed }) {
                game.tapScrambled(tile)
            } else {
                game.tapScrambled(try #require(Self.extras(in: game).first))
            }
            try await Self.waitForUnlock(game)
            #expect(game.revealedTileID == nil)
            game.tapScrambled(try Self.tile(letter, in: game))
        }

        #expect(game.missesThisWord == 3)
        #expect(game.isComplete)
        #expect(!game.didEarnStar)
        #expect(child.starCount == 0)
        #expect(game.starsThisRound == 0)
        #expect(game.wordsCompleted == 1)
    }

    @Test("Two misses on one letter light up the right tile, and the word earns no star")
    func secondMissOnALetterRevealsIt() async throws {
        let (game, child) = try Self.makeGame()
        let extras = Self.extras(in: game)

        game.tapScrambled(extras[0])
        try await Self.waitForUnlock(game)
        #expect(game.revealedTileID == nil)

        game.tapScrambled(extras[1])
        let revealed = try #require(game.scrambledLetters.first { $0.id == game.revealedTileID })
        #expect(revealed.letter == "D")
        try await Self.waitForUnlock(game)

        game.tapScrambled(revealed)
        #expect(game.revealedTileID == nil)
        game.tapScrambled(try Self.tile("O", in: game))
        game.tapScrambled(try Self.tile("G", in: game))

        #expect(game.missesThisWord == 2)
        #expect(game.isComplete)
        #expect(!game.didEarnStar, "A word that needed a letter shown isn't clean")
        #expect(child.starCount == 0)
    }

    // MARK: - Levels

    @Test("Three clean words move up a level, two without a star move back down")
    func progressionFollowsTheChild() {
        var progression = WordBuildProgression()
        #expect(progression.levelIndex == 0)

        for _ in 0..<3 { progression.record(clean: true) }
        #expect(progression.levelIndex == 1)

        for _ in 0..<3 { progression.record(clean: true) }
        #expect(progression.levelIndex == 2)

        for _ in 0..<3 { progression.record(clean: true) }
        #expect(progression.levelIndex == 2, "No level beyond the last")

        for _ in 0..<2 { progression.record(clean: false) }
        #expect(progression.levelIndex == 1)

        // A miss in between breaks a run — no change either way.
        progression.record(clean: true)
        progression.record(clean: false)
        progression.record(clean: true)
        #expect(progression.levelIndex == 1)
    }

    @Test("A new game picks up at the level saved for the child")
    func startsAtSavedLevel() throws {
        let frog = WordItem(id: "FROG", emoji: "🐸", colorIndex: 0)
        let (game, _) = try Self.makeGame(words: [Self.dog, frog], savedLevel: 2)

        #expect(game.level == WordBuildProgression.levels[2])
        #expect(game.currentWord == frog)
    }

    @Test("Moving up a level is saved to the child")
    func levelUpIsSaved() async throws {
        let (game, child) = try Self.makeGame()
        let run = WordBuildProgression.cleanRunToLevelUp

        for word in 1...run {
            try Self.spell(game)
            if word < run {
                // The next word loads once the finished one has been said.
                try await waitUntil { !game.isComplete }
            }
        }

        #expect(child.wordBuildLevel == 1)
    }

    // MARK: - Content

    @Test("Every word has no repeated letters, and each level has plenty to pick from")
    func wordListIsSound() {
        let words = WordBuildContent.words
        #expect(Set(words.map(\.id)).count == words.count, "No duplicate words")

        for word in words {
            #expect(Set(word.letters).count == word.letters.count, "\(word.id) repeats a letter")
            #expect(word.letters.allSatisfy { AlphabetContent.letter(id: $0) != nil }, "\(word.id)")
        }
        for length in Set(WordBuildProgression.levels.map(\.wordLength)) {
            #expect(words.filter { $0.letters.count == length }.count >= 12, "\(length)-letter words")
        }
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
