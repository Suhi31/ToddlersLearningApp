//
//  TraceLetterViewModel.swift
//  ToddlerLearningApp
//
//  Checkpoint-based tracing (see TracePathSampler/LetterTracePathContent): a
//  stroke counts as traced once the child's finger has visited each of its
//  ordered checkpoints, within a generous tolerance radius, with a loose
//  deviation guard rejecting points nowhere near the stroke's actual path —
//  so unlike the old region-coverage approach, a scribble can't complete a
//  trace, and multi-stroke letters (A, E, T, ...) require finishing one
//  stroke before the next one's checkpoints unlock. Session-only, like Build
//  the Word — no persisted per-letter mastery domain of its own.
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

    /// How close a touch must land to the next checkpoint to count, as a
    /// fraction of the canvas edge — wide relative to the ink stroke width,
    /// since toddler finger placement is imprecise. Proportional rather than a
    /// fixed point value so the tolerance feels the same on a 280pt phone
    /// canvas as on a 420pt iPad one; the ratios preserve the 34pt and 90pt
    /// that were hand-tuned against the original 320pt canvas.
    private static let waypointRadiusRatio: CGFloat = 34.0 / 320.0

    /// Points farther than this from the current stroke's path are ignored
    /// entirely, so a scribble far from the letter can't rack up checkpoints
    /// it never actually traced. Proportional for the same reason as above.
    private static let maxDeviationRatio: CGFloat = 90.0 / 320.0

    private var waypointRadius: CGFloat { canvasSize * Self.waypointRadiusRatio }
    private var maxDeviation: CGFloat { canvasSize * Self.maxDeviationRatio }

    private(set) var currentIndex: Int = 0
    private(set) var strokePath = Path()
    private(set) var coverage: Double = 0
    private(set) var isComplete = false
    private(set) var starsThisSession = 0
    private(set) var currentStrokeIndex = 0

    /// Fired after completing a letter and when moving to a different one —
    /// a natural break where the daily allowance may end the session (spec
    /// F5), same convention as QuizEngineViewModel. The view wires this to
    /// the coordinator; the ViewModel stays navigation-agnostic.
    var onSafeStoppingPoint: (() -> Void)?

    let child: ChildProfile
    private let speechService: SpeechServicing
    private let rewardService: RewardService
    private let haptics: HapticsService

    private var geometry: LetterTraceGeometry?
    private var nextWaypointIndex = 0
    private var totalWaypoints = 0
    private var visitedWaypoints = 0
    private var strokeLifted = true

    init(child: ChildProfile,
         speechService: SpeechServicing,
         rewardService: RewardService,
         haptics: HapticsService) {
        self.child = child
        self.speechService = speechService
        self.rewardService = rewardService
        self.haptics = haptics
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

    /// The dotted guide for every stroke in the letter, shown together so the
    /// child can see the whole shape while working through it stroke by stroke.
    var guidePaths: [Path] {
        geometry?.strokes.map(\.guidePath) ?? []
    }

    /// Where the active stroke begins — a fixed marker distinct from the
    /// moving target dot.
    var startPoint: CGPoint? {
        currentStroke?.waypoints.first
    }

    /// The next checkpoint the child needs to reach, nil once the whole
    /// letter is complete or between strokes with nothing left to target.
    var nextTargetPoint: CGPoint? {
        guard let stroke = currentStroke, nextWaypointIndex < stroke.waypoints.count else { return nil }
        return stroke.waypoints[nextWaypointIndex]
    }

    private var currentStroke: TraceStrokeGeometry? {
        guard let geometry, geometry.strokes.indices.contains(currentStrokeIndex) else { return nil }
        return geometry.strokes[currentStrokeIndex]
    }

    // MARK: - Lifecycle

    func onAppear() {
        haptics.prepare()
        setUpCurrentLetter()
    }

    func onDisappear() {
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

        if strokeLifted {
            strokePath.move(to: point)
            strokeLifted = false
        } else {
            strokePath.addLine(to: point)
        }

        registerTouch(point, stroke: stroke)
    }

    func endStroke() {
        strokeLifted = true
        guard !isComplete, let stroke = currentStroke else { return }

        // Finished this stroke's checkpoints while the finger was still down —
        // now that it's lifted, unlock the next stroke (if there is one).
        guard nextWaypointIndex >= stroke.waypoints.count,
              let geometry, currentStrokeIndex < geometry.strokes.count - 1
        else { return }

        currentStrokeIndex += 1
        nextWaypointIndex = 0
    }

    func clear() {
        strokePath = Path()
        currentStrokeIndex = 0
        nextWaypointIndex = 0
        visitedWaypoints = 0
        coverage = 0
        isComplete = false
        strokeLifted = true
    }

    // MARK: - Private

    private func setUpCurrentLetter() {
        guard let currentLetter else { return }
        rebuildGeometry()
        clear()
        speechService.speak("Trace the letter \(currentLetter.uppercase)")
    }

    private func rebuildGeometry() {
        guard let currentLetter else { return }
        geometry = TracePathSampler.geometry(for: currentLetter.id, canvasSize: canvasSize)
        totalWaypoints = geometry?.strokes.reduce(0) { $0 + $1.waypoints.count } ?? 0
    }

    private func registerTouch(_ point: CGPoint, stroke: TraceStrokeGeometry) {
        guard nextWaypointIndex < stroke.waypoints.count else { return }
        guard nearestDistance(from: point, in: stroke.densePoints) <= maxDeviation else { return }

        let target = stroke.waypoints[nextWaypointIndex]
        guard squaredDistance(point, target) <= waypointRadius * waypointRadius else { return }

        nextWaypointIndex += 1
        visitedWaypoints += 1
        coverage = totalWaypoints > 0 ? Double(visitedWaypoints) / Double(totalWaypoints) : 0
        haptics.tap()

        let isLastStroke = currentStrokeIndex == (geometry?.strokes.count ?? 1) - 1
        let strokeFinished = nextWaypointIndex >= stroke.waypoints.count
        if strokeFinished, isLastStroke {
            complete()
        }
    }

    private func complete() {
        isComplete = true
        starsThisSession += 1
        rewardService.awardStars(1, to: child)
        haptics.success()
        if let currentLetter {
            speechService.speak("Great tracing! That's \(currentLetter.uppercase).")
        }
        onSafeStoppingPoint?()
    }

    private func nearestDistance(from point: CGPoint, in path: [CGPoint]) -> CGFloat {
        path.map { hypot($0.x - point.x, $0.y - point.y) }.min() ?? .greatestFiniteMagnitude
    }

    private func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }
}
