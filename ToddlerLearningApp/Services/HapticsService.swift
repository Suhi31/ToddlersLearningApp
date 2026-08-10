//
//  HapticsService.swift
//  ToddlerLearningApp
//
//  Tactile confirmation matters more than usual here: a pre-reader who taps a
//  tile gets feedback they can feel before they can parse anything on screen.
//

import UIKit

@MainActor
final class HapticsService {

    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    /// Call just before a likely interaction to cut the actuator's latency.
    func prepare() {
        impact.prepare()
        notification.prepare()
    }

    func tap() {
        impact.impactOccurred()
    }

    func success() {
        notification.notificationOccurred(.success)
    }

    /// A soft nudge rather than `.error` — a miss should not feel like a fault.
    func gentleMiss() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
