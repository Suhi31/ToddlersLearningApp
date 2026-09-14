//
//  TraceHintTests.swift
//  ToddlerLearningAppTests
//
//  The direction hint — the ghost dot walking the stroke — on every trace
//  screen: when it comes back, what hides it, and where it starts.
//
//  Only one test waits for the timer in real time, and it only asserts that
//  the hint *does* come back, which a busy main actor can delay but not
//  break. The rest check the countdown's deadline directly.
//

import CoreGraphics
import SwiftData
import Testing

@testable import ToddlerLearningApp

@MainActor
struct TraceHintTests {

    private func makeTrace(context: ModelContext,
                           child: ChildProfile,
                           itemsPerRound: Int = 5,
                           hintDelay: Duration = .seconds(3)) -> TraceViewModel {
        TraceViewModel(kind: .letters,
                       child: child,
                       speechService: SilentSpeech(),
                       rewardService: RewardService(context: context),
                       progressService: ProgressService(context: context),
                       haptics: HapticsService(),
                       itemsPerRound: itemsPerRound,
                       hintDelay: hintDelay)
    }

    @Test("The hint plays again when the child makes no progress")
    func hintReplaysWhenIdle() async throws {
        let (context, child) = try makeTestContext()
        let trace = makeTrace(context: context, child: child, hintDelay: .milliseconds(300))

        trace.onAppear()
        try await waitUntil { trace.demoProgress != nil }
        try await waitUntil { trace.demoProgress == nil }

        // Nobody touches the screen.
        try await waitUntil { trace.demoProgress != nil }
        trace.onDisappear()
    }

    @Test("Progress pushes the hint back")
    func progressDelaysHint() async throws {
        let (context, child) = try makeTestContext()
        let trace = makeTrace(context: context, child: child)
        trace.onAppear()

        let points = try #require(trace.currentStroke).densePoints
        trace.addPoint(points[0])
        let before = try #require(trace.hintDeadline)

        try await Task.sleep(for: .milliseconds(20))
        trace.addPoint(points[1])
        let after = try #require(trace.hintDeadline)

        #expect(after > before)
        trace.onDisappear()
    }

    @Test("Tracing the wrong way leaves the hint showing; getting on the path hides it")
    func wrongTouchesKeepHint() async throws {
        let (context, child) = try makeTestContext()
        let trace = makeTrace(context: context, child: child)
        trace.onAppear()
        try await waitUntil { trace.demoProgress != nil }

        // Nowhere near A's first stroke.
        trace.addPoint(CGPoint(x: 5, y: 300))
        trace.addPoint(CGPoint(x: 10, y: 300))
        #expect(trace.demoProgress != nil)
        #expect(trace.strokeProgress == 0)

        trace.endStroke()
        trace.addPoint(try #require(trace.startPoint))
        #expect(trace.demoProgress == nil)
        trace.onDisappear()
    }

    /// The countdown is set far beyond the test so only scribbling can be what
    /// brings the hint back.
    @Test("Scribbling off the path brings the hint back without waiting for the countdown")
    func scribblingReplaysHint() async throws {
        let (context, child) = try makeTestContext()
        let trace = makeTrace(context: context, child: child, hintDelay: .seconds(30))
        trace.onAppear()
        try await waitUntil { trace.demoProgress != nil }
        try await waitUntil { trace.demoProgress == nil }

        // A small circle in the empty top-left of the canvas, well away from A.
        for step in 0..<(TraceTolerances.slipsBeforeReplay + 6) {
            let angle = CGFloat(step) * .pi / 15
            trace.addPoint(CGPoint(x: 50 + 20 * cos(angle), y: 60 + 20 * sin(angle)))
        }
        #expect(trace.strokeProgress == 0)
        try await waitUntil { trace.demoProgress != nil }
        trace.onDisappear()
    }

    @Test("A hint mid-stroke starts where the child left off, not at the stroke's start")
    func hintResumesFromProgress() async throws {
        let (context, child) = try makeTestContext()
        let trace = makeTrace(context: context, child: child)
        trace.onAppear()

        let points = try #require(trace.currentStroke).densePoints
        for point in points.prefix(7) { trace.addPoint(point) }
        trace.endStroke()
        let progress = trace.strokeProgress
        #expect(progress > 0)

        trace.playDemo()
        try await waitUntil { trace.demoProgress != nil }
        #expect(try #require(trace.demoProgress) >= progress)
        trace.onDisappear()
    }

    @Test("No hint countdown once the item is traced")
    func noHintAfterCompletion() throws {
        let (context, child) = try makeTestContext()
        let trace = makeTrace(context: context, child: child, itemsPerRound: 1)
        trace.onAppear()
        #expect(trace.hintDeadline != nil)

        let geometry = try #require(TracePathSampler.geometry(for: "A", canvasSize: trace.canvasSize))
        for (index, stroke) in geometry.strokes.enumerated() {
            for point in stroke.densePoints where trace.currentStrokeIndex == index && !trace.isComplete {
                trace.addPoint(point)
            }
            trace.endStroke()
        }

        #expect(trace.isComplete)
        #expect(trace.hintDeadline == nil)
        #expect(trace.demoProgress == nil)
        trace.onDisappear()
    }

    @Test("Try again on a finished item starts the countdown again")
    func tryAgainRestartsHint() throws {
        let (context, child) = try makeTestContext()
        let trace = makeTrace(context: context, child: child, itemsPerRound: 1)
        trace.onAppear()

        let geometry = try #require(TracePathSampler.geometry(for: "A", canvasSize: trace.canvasSize))
        for (index, stroke) in geometry.strokes.enumerated() {
            for point in stroke.densePoints where trace.currentStrokeIndex == index && !trace.isComplete {
                trace.addPoint(point)
            }
            trace.endStroke()
        }
        #expect(trace.hintDeadline == nil)

        trace.tryAgain()
        #expect(trace.hintDeadline != nil)
        trace.onDisappear()
    }
}
