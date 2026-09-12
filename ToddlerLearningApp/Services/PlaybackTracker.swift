//
//  PlaybackTracker.swift
//  ToddlerLearningApp
//
//  Knows whether one piece of audio a screen started is still playing — a
//  quiz's question, a letter's teaching sequence — so a tap that would replay
//  it can wait until it has finished instead of restarting it from the top on
//  every tap. Shared by the quizzes, Build the Word, the Learn screens and Home.
//

import Foundation

@MainActor
@Observable
final class PlaybackTracker {

    /// True from `start` until that playback returns — finished, or cut off
    /// by something newer.
    private(set) var isPlaying = false

    /// Numbers each playback, so an older one returning late — cut off by a
    /// newer one — can't clear `isPlaying` while the newer one is still going.
    @ObservationIgnored private var generation = 0

    /// Runs `playback`, tracking it until it returns. Hands back its task for
    /// a caller that also needs to cancel it.
    @discardableResult
    func start(_ playback: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        generation += 1
        let current = generation
        isPlaying = true

        return Task { [weak self] in
            await playback()
            guard let self, self.generation == current else { return }
            self.isPlaying = false
        }
    }
}
