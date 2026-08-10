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

    static let canvasSize: CGFloat = 320

    /// How close a touch must land to the next checkpoint to count, in points
    /// on a 320pt canvas — wide relative to the 16pt ink stroke width, since
    /// toddler finger placement is imprecise.
    private static let waypointRadius: CGFloat = 34

    /// Points farther than this from the current stroke's path are ignored
    /// entirely, so a scribble far from the letter can't rack up checkpoints
    /// it never actually traced.
    private static let maxDeviation: CGFloat = 90

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
        geometry = TracePathSampler.geometry(for: currentLetter.id, canvasSize: Self.canvasSize)
        totalWaypoints = geometry?.strokes.reduce(0) { $0 + $1.waypoints.count } ?? 0
        clear()
        speechService.speak("Trace the letter \(currentLetter.uppercase)")
    }

    private func registerTouch(_ point: CGPoint, stroke: TraceStrokeGeometry) {
        guard nextWaypointIndex < stroke.waypoints.count else { return }
        guard nearestDistance(from: point, in: stroke.densePoints) <= Self.maxDeviation else { return }

        let target = stroke.waypoints[nextWaypointIndex]
        guard squaredDistance(point, target) <= Self.waypointRadius * Self.waypointRadius else { return }

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
