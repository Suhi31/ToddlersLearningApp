//
//  TraceLetterViewModel.swift
//  ToddlerLearningApp
//
//  Tracing is validated as *progress along* a stroke, not as a set of
//  checkpoints that happen to get touched.
//
//  The checkpoint model it replaces accepted two things that are not tracing.
//  It never compared the finger's movement to the stroke's direction, and its
//  deviation guard took the global minimum distance to the whole stroke — so on
//  a curved letter the tolerance corridor was the entire shape and a child
//  could wander, backtrack or circle and still collect checkpoints in order.
//  It also ignored finger lifts entirely, so tapping each checkpoint in turn
//  completed a letter with no dragging at all.
//
//  Now a touch only earns progress when it is inside a corridor around the
//  stroke, within an arc-length window of where the child already is, and
//  moving *with* the stroke rather than against it. Progress is monotonic:
//  backtracking never advances it and never destroys it.
//
//  Session-only, like Build the Word — no persisted per-letter mastery domain.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class TraceLetterViewModel {

    /// The on-screen edge length of the tracing canvas, set by the view from
    /// the space it actually has. Defaults to the old fixed 320 so the view
    /// model is usable before the first layout pass reports a size.
    private(set) var canvasSize: CGFloat = 320

    private(set) var currentIndex: Int = 0
    private(set) var coverage: Double = 0
    private(set) var isComplete = false
    private(set) var starsThisSession = 0
    private(set) var currentStrokeIndex = 0

    /// Letters to finish per round (spec F27) — a finish line rather than
    /// this activity running forever. Trace is browse-shaped, not
    /// question-shaped, so a round is simply *some* `lettersPerRound`
    /// completions in whatever order the child pages to them, not a fixed
    /// sequence.
    let lettersPerRound: Int

    /// Letters completed so far in the current round.
    private(set) var lettersCompletedThisRound = 0

    /// Set once `lettersCompletedThisRound` reaches `lettersPerRound`. The
    /// view shows a celebration; `startNewRound()` clears it.
    private(set) var isRoundComplete = false

    /// How far along the active stroke the child has genuinely traced, in
    /// points of arc length. Monotonic within a stroke.
    private(set) var strokeProgress: CGFloat = 0

    /// Drives the ghost-dot demo. `nil` when no demo is playing.
    private(set) var demoProgress: CGFloat?

    /// The ink, one path per stroke: finished strokes in full, the active one
    /// trimmed to how far the child has genuinely got.
    ///
    /// Derived from progress rather than from raw touch positions, which is
    /// what makes it *impossible* to leave ink somewhere that isn't part of the
    /// letter. Drawing the finger's own path meant a touch accepted after an
    /// off-path excursion was joined to the previous accepted one with a
    /// straight line — so dragging from A's bottom-right to its middle-left
    /// drew a bar that is not part of an A.
    var tracedPaths: [Path] {
        guard let geometry else { return [] }

        // Finished letters draw every stroke in full.
        //
        // `finishStroke` folds the last stroke's length into `completedLength`
        // and resets `strokeProgress` to zero, but for the *final* stroke it
        // then completes without advancing `currentStrokeIndex` — so that
        // stroke is still the current one, with zero progress, and would
        // otherwise vanish at the exact moment the child succeeded.
        if isComplete { return geometry.strokes.map(\.guidePath) }

        return geometry.strokes.enumerated().map { index, stroke in
            if index < currentStrokeIndex { return stroke.guidePath }
            guard index == currentStrokeIndex, stroke.totalLength > 0 else { return Path() }

            let fraction = min(max(strokeProgress / stroke.totalLength, 0), 1)
            guard fraction > 0 else { return Path() }
            return stroke.guidePath.trimmedPath(from: 0, to: fraction)
        }
    }

    /// Fired after completing a letter and when moving to a different one —
    /// a natural break where the daily allowance may end the session (spec
    /// F5), same convention as QuizEngineViewModel. The view wires this to
    /// the coordinator; the ViewModel stays navigation-agnostic.
    var onSafeStoppingPoint: (() -> Void)?

    let child: ChildProfile
    private let speechService: SpeechServicing
    private let rewardService: RewardService
    private let progressService: ProgressService
    private let haptics: HapticsService

    private var geometry: LetterTraceGeometry?
    private var totalLength: CGFloat = 0
    private var completedLength: CGFloat = 0

    /// Set while the finger is down. A stroke resumed after a lift has to
    /// re-enter near where it stopped — see `addPoint`.
    private var isFingerDown = false
    private var lastPoint: CGPoint?

    /// Set by any rejected touch. While true the next touch is gated as if the
    /// finger had just come down — so wandering off the path and drifting back
    /// mid-drag has to re-enter near where progress actually stopped, rather
    /// than silently rejoining wherever the finger happens to be.
    private var needsReentry = false

    /// Consecutive rejected touches, for replaying the direction demo when a
    /// child is clearly stuck. Reset by any accepted touch.
    private var slipCount = 0
    private var demoTask: Task<Void, Never>?

    private var tolerances: TraceTolerances { TraceTolerances(canvasSize: canvasSize) }

    init(child: ChildProfile,
         speechService: SpeechServicing,
         rewardService: RewardService,
         progressService: ProgressService,
         haptics: HapticsService,
         lettersPerRound: Int = 5) {
        self.child = child
        self.speechService = speechService
        self.rewardService = rewardService
        self.progressService = progressService
        self.haptics = haptics
        self.lettersPerRound = lettersPerRound
    }

    var letters: [Letter] { AlphabetContent.letters }

    var currentLetter: Letter? {
        guard letters.indices.contains(currentIndex) else { return nil }
        return letters[currentIndex]
    }

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < letters.count - 1 }

    var positionCaption: String {
        "\(currentIndex + 1) of \(letters.count)"
    }

    var strokeCount: Int { geometry?.strokes.count ?? 0 }

    /// Every stroke's dotted guide, shown together so the child can see the
    /// whole shape while working through it one stroke at a time. Precomputed
    /// on `LetterTraceGeometry` — this just forwards it.
    var guidePaths: [Path] {
        geometry?.guidePaths ?? []
    }

    /// The stroke currently being traced.
    var currentStroke: TraceStrokeGeometry? {
        guard let geometry, geometry.strokes.indices.contains(currentStrokeIndex) else { return nil }
        return geometry.strokes[currentStrokeIndex]
    }

    /// Where the active stroke begins.
    var startPoint: CGPoint? { currentStroke?.start }

    /// Where each stroke begins, for the stroke-order badges.
    var strokeStartPoints: [CGPoint] {
        geometry?.strokes.compactMap(\.start) ?? []
    }

    /// The point the child should be heading for next, a little ahead of where
    /// they are, with the direction to travel in.
    var nextTarget: (point: CGPoint, tangent: CGVector)? {
        guard !isComplete, let stroke = currentStroke else { return nil }
        let ahead = min(strokeProgress + tolerances.lookAhead * 0.6, stroke.totalLength)
        guard let point = stroke.point(atArcLength: ahead),
              let tangent = stroke.tangent(atArcLength: ahead) else { return nil }
        return (point, tangent)
    }

    /// Arrowheads along every stroke's guide, so the direction to travel is
    /// visible before the child starts rather than only once they are moving.
    /// Precomputed per stroke on `TraceStrokeGeometry` — this only flattens
    /// them and attaches the stroke index, instead of recomputing every
    /// marker's point and tangent from a `Canvas` render closure on every
    /// touch point at 60 Hz.
    var directionMarkers: [(point: CGPoint, tangent: CGVector, strokeIndex: Int)] {
        guard let geometry else { return [] }
        return geometry.strokes.enumerated().flatMap { index, stroke in
            stroke.directionMarkers.map { (point: $0.point, tangent: $0.tangent, strokeIndex: index) }
        }
    }

    // MARK: - Lifecycle

    func onAppear() {
        haptics.prepare()
        setUpCurrentLetter()
    }

    func onDisappear() {
        demoTask?.cancel()
        demoTask = nil
        speechService.stop()
    }

    /// Speaks the current letter again. Exposed for the canvas's VoiceOver
    /// action: a VoiceOver user gets nothing from the dotted visual guide, so
    /// hearing which letter is being traced is the only way in.
    func speakCurrentLetter() {
        guard let currentLetter else { return }
        speechService.speak("Trace the letter \(currentLetter.uppercase)")
    }

    /// Called by the view once it knows how much room it actually has. Every
    /// sampled coordinate is in canvas space, so a size change invalidates the
    /// geometry and any half-drawn stroke — but it must not re-speak the
    /// letter, since this is a layout event, not a navigation one.
    func updateCanvasSize(_ size: CGFloat) {
        let resolved = max(size, 1)
        guard abs(resolved - canvasSize) > 0.5 else { return }
        canvasSize = resolved
        rebuildGeometry()
        clear()
        playDemo()
    }

    func next() {
        guard canGoForward else { return }
        currentIndex += 1
        haptics.tap()
        setUpCurrentLetter()
        onSafeStoppingPoint?()
    }

    func previous() {
        guard canGoBack else { return }
        currentIndex -= 1
        haptics.tap()
        setUpCurrentLetter()
        onSafeStoppingPoint?()
    }

    // MARK: - Drawing

    func addPoint(_ point: CGPoint) {
        guard !isComplete, let stroke = currentStroke else { return }

        // Any touch cancels the demo — it must never fight the child's input.
        cancelDemo()

        // A lift is inferred from the geometry as well as taken from the
        // gesture. `endStroke` fires on `onEnded`, but a cancelled or
        // interrupted gesture can skip it, and if `isFingerDown` gets stuck
        // true every later touch would bypass the resume gate — which is
        // exactly the tap-tap-tap hole this validator exists to close. A jump
        // no finger could make between two touch events means the finger left
        // the glass, whatever the gesture system reported.
        let jumped = lastPoint.map { distance(point, $0) > tolerances.liftJump } ?? false
        let isTouchDown = !isFingerDown || jumped || needsReentry
        isFingerDown = true
        defer { lastPoint = point }

        guard gateEntry(point, stroke: stroke, isTouchDown: isTouchDown) else {
            // Not a valid place to be drawing — no ink, no progress. The
            // absence of progress is the feedback (spec F4: non-punitive).
            registerSlip()
            return
        }

        guard let advanced = advance(to: point, stroke: stroke) else {
            registerSlip()
            return
        }

        needsReentry = false
        slipCount = 0

        if advanced {
            haptics.tap()
        }

        if strokeProgress >= stroke.totalLength * tolerances.completionFraction {
            finishStroke(stroke)
        }
    }

    func endStroke() {
        isFingerDown = false
        lastPoint = nil
        // Progress is deliberately kept: a lifted finger may resume, but only
        // near where it stopped. See `gateEntry`.
    }

    /// The "Try again" button's action (spec F28) — distinct from `clear()`,
    /// which is also called internally on canvas-size changes and must never
    /// itself record a miss just because the device rotated. Only counts as
    /// a miss when there was genuine progress to abandon: restarting a fresh,
    /// untouched letter — or one already completed — isn't one. The 25%
    /// threshold is a judgement call, not a spec'd number: low enough that a
    /// child who barely started isn't penalised for exploring, high enough
    /// that giving up partway through registers as the shaky attempt it was.
    func tryAgain() {
        if !isComplete, coverage > 0.25, let currentLetter {
            progressService.recordTrace(child: child, letterID: currentLetter.id, completed: false)
        }
        clear()
    }

    func clear() {
        currentStrokeIndex = 0
        strokeProgress = 0
        completedLength = 0
        coverage = 0
        isComplete = false
        isFingerDown = false
        lastPoint = nil
        needsReentry = false
        slipCount = 0
    }

    // MARK: - Validation

    /// Decides whether the finger is somewhere it is allowed to be drawing:
    /// at the start of a fresh stroke, or back where it left off after a lift.
    private func gateEntry(_ point: CGPoint,
                           stroke: TraceStrokeGeometry,
                           isTouchDown: Bool) -> Bool {
        guard isTouchDown else { return true }

        if strokeProgress <= 0 {
            // A stroke has to be started at its beginning, otherwise a child
            // can begin anywhere and the direction cues mean nothing.
            guard let start = stroke.start else { return false }
            return distance(point, start) <= tolerances.startRadius
        }

        // Mid-stroke touch-down: only counts near where the finger left off.
        // This is what makes tapping each part of a stroke in turn fail while
        // still forgiving a grip that slipped.
        guard let resumePoint = stroke.point(atArcLength: strokeProgress) else { return false }
        return distance(point, resumePoint) <= tolerances.resumeRadius
    }

    /// Returns nil when the touch earns nothing, or whether it moved progress.
    private func advance(to point: CGPoint, stroke: TraceStrokeGeometry) -> Bool? {
        let window = (strokeProgress - tolerances.lookBehind)...(strokeProgress + tolerances.lookAhead)

        guard let hit = stroke.project(point, within: window),
              hit.distance <= tolerances.corridor else { return nil }

        // Direction: the finger must be travelling with the stroke, not against
        // it. Skipped for movements too small to have a meaningful direction.
        if let lastPoint {
            let movement = CGVector(dx: point.x - lastPoint.x, dy: point.y - lastPoint.y)
            let travelled = hypot(movement.dx, movement.dy)

            if travelled >= tolerances.minimumMovement {
                let agreement = (movement.dx * hit.tangent.dx + movement.dy * hit.tangent.dy) / travelled
                guard agreement > tolerances.directionAgreement else { return nil }
            }
        }

        let didAdvance = hit.arcLength > strokeProgress
        strokeProgress = max(strokeProgress, hit.arcLength)
        updateCoverage()
        return didAdvance
    }

    private func registerSlip() {
        needsReentry = true
        slipCount += 1
        guard slipCount >= TraceTolerances.slipsBeforeReplay else { return }
        slipCount = 0
        haptics.gentleMiss()
        playDemo()
    }

    private func finishStroke(_ stroke: TraceStrokeGeometry) {
        completedLength += stroke.totalLength
        strokeProgress = 0
        updateCoverage()

        guard let geometry, currentStrokeIndex < geometry.strokes.count - 1 else {
            complete()
            return
        }

        currentStrokeIndex += 1
        isFingerDown = false
        lastPoint = nil
        playDemo()
    }

    private func updateCoverage() {
        guard totalLength > 0 else { return coverage = 0 }
        coverage = min(1, Double((completedLength + strokeProgress) / totalLength))
    }

    // MARK: - Direction demo

    /// Walks a ghost dot along the active stroke to show which way to go.
    /// Played when a letter appears and again when a child is clearly stuck.
    func playDemo() {
        guard let stroke = currentStroke, stroke.totalLength > 0, !isComplete else { return }

        demoTask?.cancel()
        demoTask = Task { [weak self] in
            guard let self else { return }

            let steps = 60
            for step in 0...steps {
                guard !Task.isCancelled else { return }
                demoProgress = stroke.totalLength * CGFloat(step) / CGFloat(steps)
                try? await Task.sleep(for: .milliseconds(16))
            }

            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            demoProgress = nil
        }
    }

    private func cancelDemo() {
        guard demoProgress != nil || demoTask != nil else { return }
        demoTask?.cancel()
        demoTask = nil
        demoProgress = nil
    }

    // MARK: - Private

    private func setUpCurrentLetter() {
        guard let currentLetter else { return }
        rebuildGeometry()
        clear()
        speechService.speak("Trace the letter \(currentLetter.uppercase)")
        playDemo()
    }

    private func rebuildGeometry() {
        guard let currentLetter else { return }
        geometry = TracePathSampler.geometry(for: currentLetter.id, canvasSize: canvasSize)
        totalLength = geometry?.strokes.reduce(0) { $0 + $1.totalLength } ?? 0
    }

    /// Starts a fresh round from zero — the "Play again" action on the
    /// round-complete celebration. Trace is browse-shaped: this leaves the
    /// child on whatever letter they're viewing rather than picking a new
    /// one, since paging to the next letter is already how the activity works.
    func startNewRound() {
        lettersCompletedThisRound = 0
        isRoundComplete = false
    }

    private func complete() {
        isComplete = true
        cancelDemo()
        starsThisSession += 1
        rewardService.awardStars(1, to: child)
        haptics.success()
        if let currentLetter {
            speechService.speak("Great tracing! That's \(currentLetter.uppercase).")
            progressService.recordTrace(child: child, letterID: currentLetter.id, completed: true)
        }

        lettersCompletedThisRound += 1
        if lettersCompletedThisRound >= lettersPerRound {
            isRoundComplete = true
        }

        onSafeStoppingPoint?()
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
