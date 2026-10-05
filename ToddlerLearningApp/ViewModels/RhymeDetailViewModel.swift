//
//  RhymeDetailViewModel.swift
//  ToddlerLearningApp
//
//  The player for one rhyme — and, since it can move between them, for the
//  whole list. `RhymeAudioService` is `@Observable`, so `isPlaying`/`progress`
//  drive SwiftUI directly and this simply reads through to them.
//
//  Moving to another rhyme swaps it *in place* rather than pushing a second
//  detail screen. That is not a style preference: `RhymeAudioPlaying` is a
//  single shared instance (see `AppDependencies`), and on a push the outgoing
//  screen's `onDisappear` lands ~0.6s late — after the incoming screen has
//  already started singing — so it would stop the new rhyme and clear the
//  `onFinished` claim that drives autoplay. `ScopedSpeechService` documents the
//  same trap for speech, which has its own scoping; rhyme audio has none.
//

import Foundation

@MainActor
@Observable
final class RhymeDetailViewModel {

    private let rhymes: [Rhyme]

    private(set) var index: Int

    var rhyme: Rhyme { rhymes[index] }

    var isPlaying: Bool { rhymeAudioService.isPlaying }
    var progress: Double { rhymeAudioService.progress }

    var canGoPrevious: Bool { index > 0 }

    /// Position in the list only — deliberately *not* the transport lock. These
    /// drive `ArrowNavBar`'s `.disabled()`, and arrows greying out for a beat
    /// after every tap reads as a broken app. The lock is enforced inside
    /// `next()`/`previous()` instead.
    var canGoNext: Bool { index < rhymes.count - 1 }

    /// Swallows the second tap of a mash. See `togglePlayback()`.
    private(set) var isTransportLocked = false

    /// Fired when a rhyme ends or the child moves to another one — a natural
    /// break where the daily allowance may end the session (spec F5), same
    /// convention as QuizEngineViewModel. The view wires this to the
    /// coordinator; this class stays navigation-agnostic.
    var onSafeStoppingPoint: (() -> Void)?

    /// Asked before autoplay moves on to the next rhyme. The view answers with
    /// everything the coordinator knows — chiefly whether "All done" is up —
    /// which keeps navigation out of here, like `onSafeStoppingPoint`.
    var canContinuePlaying: (() -> Bool)?

    private let rhymeAudioService: RhymeAudioPlaying
    private let haptics: HapticsService

    /// Reloaded on every swap. Stale cues highlight another song's lines and
    /// fail silently, so this is the one piece of state worth being loud about.
    private var cues: RhymeCues?

    private var lockTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?

    /// `onAppear` fires again on the way *back* from "Practice letter B", and a
    /// rhyme the child paused must not restart under them.
    private var hasAutoplayed = false

    /// Long enough to swallow a mash — toddler repeat-taps cluster at
    /// 150-400ms — and short enough that a deliberate pause still works.
    private static let transportLock: Duration = .milliseconds(800)

    /// The first sung line shouldn't have to compete with the push animation
    /// and whatever the previous screen was still saying.
    private static let openingDelay: Duration = .milliseconds(300)

    init(rhyme: Rhyme,
         rhymes: [Rhyme] = RhymeContent.rhymes,
         rhymeAudioService: RhymeAudioPlaying,
         haptics: HapticsService) {
        // Falling back to a single-item list keeps `rhyme` honest if the one
        // asked for isn't in the list; the arrows simply have nowhere to go.
        let list = rhymes.contains(rhyme) ? rhymes : [rhyme]
        self.rhymes = list
        self.index = list.firstIndex(of: rhyme) ?? 0
        self.rhymeAudioService = rhymeAudioService
        self.haptics = haptics
        self.cues = RhymeCues.load(for: rhyme)
    }

    // MARK: - Lifecycle

    func onAppear() {
        haptics.prepare()
        rhymeAudioService.onFinished = { [weak self] in self?.handleFinished() }

        guard !hasAutoplayed, !rhymeAudioService.isPlaying else { return }
        hasAutoplayed = true
        startPlaying(after: Self.openingDelay)
    }

    func onDisappear() {
        startTask?.cancel()
        lockTask?.cancel()
        isTransportLocked = false
        rhymeAudioService.onFinished = nil
        // Paused, not stopped: the rhymes grid marks the one the child is on,
        // and coming back resumes rather than starting the song over.
        rhymeAudioService.pause()
    }

    /// Belt and braces for the daily allowance. "All done" is a
    /// `fullScreenCover`, and a covered view doesn't reliably get
    /// `onDisappear` — without this a rhyme sings on underneath it.
    func stopForTimeUp() {
        startTask?.cancel()
        rhymeAudioService.stop()
    }

    // MARK: - Intent

    func togglePlayback() {
        // Before the guard, deliberately. A swallowed tap must still squash and
        // buzz: a tap that produces nothing makes a child tap harder and then
        // give up, so only the *audio* is ever protected, never the feedback.
        // For the same reason the button is never `.disabled()` — a disabled
        // SwiftUI button gets no press state, so it can't bounce at all.
        haptics.tap()
        guard !isTransportLocked else { return }

        if rhymeAudioService.isPlaying {
            // Pausing is never locked: a child reaching to restart must not
            // meet a dead button.
            rhymeAudioService.pause()
        } else if rhymeAudioService.progress > 0 {
            rhymeAudioService.resume()
            lockTransport()
        } else {
            startPlaying()
        }
    }

    func next() {
        haptics.tap()
        guard !isTransportLocked, canGoNext else { return }
        move(to: index + 1)
        onSafeStoppingPoint?()
    }

    func previous() {
        haptics.tap()
        guard !isTransportLocked, canGoPrevious else { return }
        move(to: index - 1)
        onSafeStoppingPoint?()
    }

    /// Approximate karaoke-style sync, from the recording's own measured line
    /// timings. The even-split fallback below only holds when every line takes
    /// the same time and is sung exactly once — true of the read-aloud path,
    /// false of every real recording, where verses repeat.
    var highlightedLineIndex: Int? {
        guard isPlaying, !rhyme.lines.isEmpty else { return nil }

        if let cues {
            guard let line = cues.line(at: rhymeAudioService.currentTime) else { return nil }
            return min(max(line, 0), rhyme.lines.count - 1)
        }

        let index = Int(progress * Double(rhyme.lines.count))
        return min(max(index, 0), rhyme.lines.count - 1)
    }

    // MARK: - Flow

    /// The one way the current rhyme ever changes, so the reset list below
    /// can't drift between the callers.
    private func move(to newIndex: Int) {
        guard rhymes.indices.contains(newIndex) else { return }

        rhymeAudioService.stop()
        index = newIndex
        cues = RhymeCues.load(for: rhyme)
        startPlaying()
    }

    private func startPlaying(after delay: Duration = .zero) {
        startTask?.cancel()
        let rhyme = rhyme
        startTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled, let self else { return }
            self.rhymeAudioService.play(rhyme)
            self.lockTransport()
        }
    }

    /// A rhyme reached its end. Order matters: the stopping point is what lets
    /// the coordinator raise "All done", and the very next line asks whether
    /// we may keep going.
    private func handleFinished() {
        onSafeStoppingPoint?()

        guard canContinuePlaying?() ?? true else {
            rhymeAudioService.stop()
            return
        }
        // The last rhyme simply stops — no looping, and no yanking the child
        // back to the grid.
        guard canGoNext else { return }
        move(to: index + 1)
    }

    private func lockTransport() {
        lockTask?.cancel()
        isTransportLocked = true
        lockTask = Task { [weak self] in
            try? await Task.sleep(for: Self.transportLock)
            guard !Task.isCancelled else { return }
            self?.isTransportLocked = false
        }
    }
}
