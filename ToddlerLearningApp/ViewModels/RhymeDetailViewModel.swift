//
//  RhymeDetailViewModel.swift
//  ToddlerLearningApp
//
//  The player for a single rhyme. Owns both SpeechServicing and
//  RhymeAudioPlaying, which is where the two playback paths get coordinated —
//  RhymeAudioService and SpeechService don't know about each other, since a
//  ViewModel that already holds both is the natural place for that, not a
//  dependency between two otherwise-unrelated leaf services.
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

    private let speechService: SpeechServicing
    private let rhymeAudioService: RhymeAudioPlaying
    private let haptics: HapticsService

    init(rhyme: Rhyme,
         speechService: SpeechServicing,
         rhymeAudioService: RhymeAudioPlaying,
         haptics: HapticsService) {
        self.rhyme = rhyme
        self.speechService = speechService
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
            speechService.stop()
            rhymeAudioService.play(rhyme)
        }
    }
}
