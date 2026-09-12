//
//  RhymeDetailViewModel.swift
//  ToddlerLearningApp
//
//  The player for a single rhyme, over RhymeAudioPlaying. It used to hold
//  SpeechServicing as well, only to silence speech before a rhyme started —
//  unnecessary now that each screen's speech is stopped by that screen when
//  it leaves (see ScopedSpeechService), and this screen never speaks itself.
//
//  `RhymeAudioService` is `@Observable`, so its `isPlaying`/`progress` drive
//  SwiftUI directly and this simply reads through to them. It used to copy
//  them into its own stored properties via a 200ms poll that ran for the whole
//  time the screen was open, playing or not.
//

import Foundation

@MainActor
@Observable
final class RhymeDetailViewModel {

    let rhyme: Rhyme

    var isPlaying: Bool { rhymeAudioService.isPlaying }
    var progress: Double { rhymeAudioService.progress }

    /// Fired when the rhyme finishes playing — a natural break where the
    /// daily allowance may end the session (spec F5), same convention as
    /// QuizEngineViewModel. The view wires this to the coordinator.
    var onSafeStoppingPoint: (() -> Void)?

    private let rhymeAudioService: RhymeAudioPlaying
    private let haptics: HapticsService

    init(rhyme: Rhyme,
         rhymeAudioService: RhymeAudioPlaying,
         haptics: HapticsService) {
        self.rhyme = rhyme
        self.rhymeAudioService = rhymeAudioService
        self.haptics = haptics
    }

    /// Approximate karaoke-style sync: evenly divides playback progress
    /// across the lyric lines rather than requiring per-line timestamps to be
    /// authored for every rhyme. Good enough for a toddler following along;
    /// a real timestamp track would make this exact if it ever feels off.
    var highlightedLineIndex: Int? {
        guard isPlaying, !rhyme.lines.isEmpty else { return nil }
        let index = Int(progress * Double(rhyme.lines.count))
        return min(max(index, 0), rhyme.lines.count - 1)
    }

    func onAppear() {
        haptics.prepare()
        rhymeAudioService.onFinished = { [weak self] in
            self?.onSafeStoppingPoint?()
        }
    }

    func onDisappear() {
        rhymeAudioService.onFinished = nil
        rhymeAudioService.stop()
    }

    func togglePlayback() {
        haptics.tap()
        if rhymeAudioService.isPlaying {
            rhymeAudioService.pause()
        } else if rhymeAudioService.progress > 0 {
            rhymeAudioService.resume()
        } else {
            rhymeAudioService.play(rhyme)
        }
    }
}
