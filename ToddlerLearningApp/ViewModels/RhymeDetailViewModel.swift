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
//  RhymeAudioService itself isn't @Observable, so its `isPlaying`/`progress`
//  mutating internally wouldn't trigger a SwiftUI re-render on its own — this
//  polls them into this view model's own tracked stored properties instead,
//  the same "own stored state, not someone else's" requirement every
//  @Observable view model in this app already follows.
//

import Foundation

@MainActor
@Observable
final class RhymeDetailViewModel {

    let rhyme: Rhyme

    private(set) var isPlaying = false
    private(set) var progress: Double = 0

    /// Fired when the rhyme finishes playing — a natural break where the
    /// daily allowance may end the session (spec F5), same convention as
    /// QuizEngineViewModel. The view wires this to the coordinator.
    var onSafeStoppingPoint: (() -> Void)?

    private let speechService: SpeechServicing
    private let rhymeAudioService: RhymeAudioPlaying
    private let haptics: HapticsService

    private var pollTask: Task<Void, Never>?
    private var wasPlaying = false

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
        startPolling()
    }

    func onDisappear() {
        pollTask?.cancel()
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
        syncFromService()
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                syncFromService()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func syncFromService() {
        let newIsPlaying = rhymeAudioService.isPlaying
        let newProgress = rhymeAudioService.progress

        // A transition from playing to stopped-at-the-start (rather than
        // paused mid-track, which leaves progress > 0) is how a natural
        // finish shows up through this polling — RhymeAudioService.stop()
        // resets progress to 0, pause() doesn't.
        if wasPlaying, !newIsPlaying, newProgress == 0 {
            onSafeStoppingPoint?()
        }

        wasPlaying = newIsPlaying
        isPlaying = newIsPlaying
        progress = newProgress
    }
}
