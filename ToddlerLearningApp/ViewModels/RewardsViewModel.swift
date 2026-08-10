//
//  RewardsViewModel.swift
//  ToddlerLearningApp
//

import Foundation

@MainActor
@Observable
final class RewardsViewModel {

    let child: ChildProfile
    private let rewardService: RewardService

    init(child: ChildProfile, rewardService: RewardService) {
        self.child = child
        self.rewardService = rewardService
    }

    var trophies: [Trophy] { rewardService.trophies(for: child) }
    var unlockedTrophies: [Trophy] { trophies.filter(\.isUnlocked) }
    var starCount: Int { child.starCount }
    var streak: Int { child.currentStreak }

    var summary: String {
        "\(unlockedTrophies.count) of \(trophies.count) trophies"
    }

    /// Phrased as an invitation rather than a warning — a lapsed streak should
    /// never read as something the child lost (spec F4).
    var streakCaption: String {
        switch streak {
        case 0: "Play today to start a streak!"
        case 1: "You played today! 🔥"
        default: "\(streak) days in a row! 🔥"
        }
    }
}
