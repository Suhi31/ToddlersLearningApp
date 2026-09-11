//
//  HomeViewModelTests.swift
//  ToddlerLearningAppTests
//
//  The daily-goal line on Home (spec F4).
//

import Foundation
import SwiftData
import Testing

@testable import ToddlerLearningApp

@MainActor
struct HomeViewModelTests {

    private static func makeHome(starsToday: Int) throws -> HomeViewModel {
        let container = try ModelContainer(
            for: ChildProfile.self, LetterProgress.self, NumberProgress.self, TraceProgress.self, SessionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // Not `container.mainContext` — see `ProgressServiceTests.makeService`.
        let context = ModelContext(container)
        let child = ChildProfile(name: "Test", age: 4, avatarEmoji: "🐰")
        child.starsEarnedToday = starsToday
        child.starsEarnedTodayDate = .now
        context.insert(child)
        return HomeViewModel(child: child,
                             sessionTimer: SessionTimerService(context: context),
                             speechService: HeldSpeech(),
                             haptics: HapticsService())
    }

    @Test("Below the goal, the line counts toward it")
    func countsTowardGoal() throws {
        let home = try Self.makeHome(starsToday: 3)
        #expect(home.dailyGoalCaption == "3 of \(RewardService.dailyGoalTarget) stars today")
    }

    /// Exactly at the goal, and far past it — the "41 of 5" case.
    @Test("At or past the goal, the line says it's reached rather than overflowing")
    func reachedGoal() throws {
        for starsToday in [RewardService.dailyGoalTarget, 41] {
            let home = try Self.makeHome(starsToday: starsToday)
            #expect(home.dailyGoalCaption == "Goal reached! 🎉", "\(starsToday) stars")
            #expect(home.dailyGoalProgress == 1, "\(starsToday) stars")
        }
    }
}
