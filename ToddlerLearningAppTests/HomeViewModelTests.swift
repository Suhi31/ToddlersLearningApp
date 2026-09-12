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
        let (context, child) = try makeTestContext()
        child.starsEarnedToday = starsToday
        child.starsEarnedTodayDate = .now
        return HomeViewModel(child: child,
                             sessionTimer: SessionTimerService(context: context),
                             speechService: SilentSpeech(),
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
