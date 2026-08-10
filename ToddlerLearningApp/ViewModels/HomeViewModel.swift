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
    var overallProgress: Double { child.overallProgress }

    var progressCaption: String {
        "\(child.masteredCount) of \(child.unlockedLetters.count) letters mastered"
    }

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

    func tapLetterOfDay() {
        guard let letterOfTheDay else { return }
        haptics.tap()
        Task { await speechService.teachLetter(letterOfTheDay) }
    }
}
