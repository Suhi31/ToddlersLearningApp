//
//  HomeViewModel.swift
//  ToddlerLearningApp
//

import Foundation

@MainActor
@Observable
final class HomeViewModel {

    let child: ChildProfile

    private let sessionTimer: SessionTimerService
    private let speechService: SpeechServicing
    private let haptics: HapticsService

    /// Tracks `tapLetterOfDay`'s teaching sequence so a second tap — or
    /// leaving Home entirely — can cancel it. Without this, a child tapping
    /// the letter-of-the-day pill repeatedly (the expected way to use it)
    /// started overlapping 3-beat sequences: the second call's `stop()`
    /// resumed the first sequence's paused beat, which then carried on to
    /// its next beat and spoke over the second. Every other screen with a
    /// multi-beat speech sequence tracks its task the same way — see
    /// `BrowsingViewModel.speechTask` — Home was the one that didn't.
    private var speechTask: Task<Void, Never>?

    init(child: ChildProfile,
         sessionTimer: SessionTimerService,
         speechService: SpeechServicing,
         haptics: HapticsService) {
        self.child = child
        self.sessionTimer = sessionTimer
        self.speechService = speechService
        self.haptics = haptics
    }

    var greeting: String {
        child.name.isEmpty ? "Hi there! 👋" : "Hi \(child.name)! 👋"
    }

    var avatar: String { child.avatarEmoji }
    var starCount: Int { child.starCount }
    var streak: Int { child.currentStreak }

    /// Spec F4's daily goal — never shown as "missed," just a plain count
    /// that silently reads 0 again once a new day starts.
    var dailyGoalProgress: Double {
        min(1, Double(child.starsEarnedTodayCount) / Double(RewardService.dailyGoalTarget))
    }

    var dailyGoalCaption: String {
        "\(child.starsEarnedTodayCount) of \(RewardService.dailyGoalTarget) stars today"
    }

    /// Shown to the child as a soft heads-up rather than a countdown, and only
    /// near the end — a visible timer running all session is its own pressure.
    var timeRemainingCaption: String? {
        guard sessionTimer.hasLimit else { return nil }
        let minutes = sessionTimer.remainingSeconds / 60
        guard minutes <= 5 else { return nil }
        return minutes <= 1 ? "Almost time to finish!" : "\(minutes) more minutes"
    }

    /// A different letter each day, deterministic from the calendar so it holds
    /// steady across relaunches within the same day rather than reshuffling
    /// every time Home appears.
    var letterOfTheDay: Letter? {
        let letters = child.unlockedLetters
        guard !letters.isEmpty else { return nil }
        let dayOfYear = (Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1) - 1
        return letters[dayOfYear % letters.count]
    }

    // MARK: - Intent

    /// A child taps the mascot over and over — the exact same reply every
    /// time is precisely what reads as robotic at that kind of repetition,
    /// so this picks from a handful of greetings instead of one fixed line.
    func tapMascot() {
        haptics.tap()
        // Cancels any in-flight `tapLetterOfDay` sequence so its remaining
        // beats can't resume and speak over this line — see `speechTask`.
        speechTask?.cancel()
        let templates = [
            "Hi %@! Ready to play?",
            "Hello %@! Let's have some fun!",
            "Hey %@! Ready for an adventure?",
            "Hiya %@! What should we learn today?",
            "Boo! Just kidding, %@ — let's play!"
        ]
        let name = child.name.isEmpty ? "there" : child.name
        let phrase = String(format: templates.randomElement() ?? templates[0], name)
        speechService.speak(phrase)
    }

    /// Whether the letter of the day is still being taught. Another tap on
    /// the pill while it is does nothing — restarting the same sequence from
    /// the top on every tap only makes it stutter. The mascot's greeting still
    /// cuts in, since that's a different line.
    private(set) var isTeachingLetterOfDay = false

    /// Numbers each teach sequence — same role as `BrowsingViewModel`'s.
    private var letterOfDayPlayback = 0

    func tapLetterOfDay() {
        guard let letterOfTheDay, !isTeachingLetterOfDay else { return }
        haptics.tap()
        speechTask?.cancel()
        speechService.stop()
        letterOfDayPlayback += 1
        let playback = letterOfDayPlayback
        isTeachingLetterOfDay = true
        speechTask = Task { [weak self, speechService] in
            await speechService.teachLetter(letterOfTheDay)
            guard let self, self.letterOfDayPlayback == playback else { return }
            self.isTeachingLetterOfDay = false
        }
    }

    /// Called when Home disappears, so a teaching sequence started by the
    /// letter-of-the-day pill doesn't keep talking over whatever screen the
    /// child navigated to next.
    func onDisappear() {
        speechTask?.cancel()
        speechService.stop()
    }
}
