//
//  TraceNumberTests.swift
//  ToddlerLearningAppTests
//
//  Trace Numbers: the digit set and its stroke shapes, that every traceable
//  item — digits and letters alike — can actually be finished by following
//  its own strokes, and where a traced digit's progress goes.
//

import CoreGraphics
import SwiftData
import Testing

@testable import ToddlerLearningApp

@MainActor
struct TraceNumberTests {

    private func makeTrace(_ kind: TraceKind,
                           context: ModelContext,
                           child: ChildProfile,
                           speech: SpeechServicing? = nil) -> TraceViewModel {
        TraceViewModel(kind: kind,
                       child: child,
                       speechService: speech ?? SilentSpeech(),
                       rewardService: RewardService(context: context),
                       progressService: ProgressService(context: context),
                       haptics: HapticsService(),
                       itemsPerRound: 100)
    }

    /// Drags along each stroke of the current item, point by point, lifting
    /// between strokes — an ideal finger, so a failure means the shape itself
    /// can't be traced, not that the child wobbled.
    private func traceCurrentItem(_ trace: TraceViewModel) throws {
        let item = try #require(trace.currentItem)
        let geometry = try #require(TracePathSampler.geometry(for: item.id, canvasSize: trace.canvasSize))

        for (index, stroke) in geometry.strokes.enumerated() {
            for point in stroke.densePoints where trace.currentStrokeIndex == index && !trace.isComplete {
                trace.addPoint(point)
            }
            trace.endStroke()
        }
    }

    // MARK: - Content

    @Test("Trace Numbers is the ten digits, 0 to 9, each with strokes to trace")
    func digitsAreZeroToNine() throws {
        let items = TraceKind.numbers.items
        #expect(items.map(\.id) == (0...9).map { "\($0)" })

        for item in items {
            let geometry = try #require(TracePathSampler.geometry(for: item.id, canvasSize: 320),
                                        "no strokes for \(item.id)")
            #expect(!geometry.strokes.isEmpty)
            for stroke in geometry.strokes {
                #expect(stroke.totalLength > 0, "\(item.id) has an empty stroke")
            }
        }
    }

    /// The faint shape behind the guide is stroked 13% of the canvas wide, so
    /// a path closer to the edge than half that gets clipped.
    @Test("Every digit sits clear of the canvas edges")
    func digitsFitTheCanvas() throws {
        let canvas: CGFloat = 320
        let margin = canvas * 0.07

        for item in TraceKind.numbers.items {
            let geometry = try #require(TracePathSampler.geometry(for: item.id, canvasSize: canvas))
            for point in geometry.strokes.flatMap(\.densePoints) {
                #expect((margin...(canvas - margin)).contains(point.x), "\(item.id) runs off at \(point)")
                #expect((margin...(canvas - margin)).contains(point.y), "\(item.id) runs off at \(point)")
            }
        }
    }

    /// Tracing enforces direction, so this is what a child is taught. 0 goes
    /// the same way as the letter O, and 9 the opposite way to 6 — it is the
    /// 6 turned upside down and started from the loop.
    @Test("0 and 9 run clockwise like the letter O; 6 runs counter-clockwise")
    func roundDigitDirections() throws {
        // Shoelace sum over the stroke, closed back to its start. With y
        // pointing down, clockwise on screen is positive. For 6 and 9 the tail
        // turns the same way as the loop, so it only adds to the sign.
        func signedArea(_ id: String) throws -> CGFloat {
            let points = try #require(TracePathSampler.geometry(for: id, canvasSize: 320)).strokes[0].densePoints
            return zip(points, points.dropFirst() + [points[0]])
                .reduce(0) { $0 + ($1.0.x * $1.1.y - $1.1.x * $1.0.y) }
        }

        #expect(try signedArea("O") > 0)
        #expect(try signedArea("0") > 0)
        #expect(try signedArea("9") > 0)
        #expect(try signedArea("6") < 0)
    }

    @Test("9 is one stroke, the 6 turned upside down")
    func nineIsSixUpsideDown() throws {
        let canvas: CGFloat = 320
        let six = try #require(TracePathSampler.geometry(for: "6", canvasSize: canvas)).strokes
        let nine = try #require(TracePathSampler.geometry(for: "9", canvasSize: canvas)).strokes
        #expect(six.count == 1)
        #expect(nine.count == 1)

        // Half a turn about the centre, drawn in the opposite order.
        let rotatedSix = six[0].densePoints.reversed().map { CGPoint(x: canvas - $0.x, y: canvas - $0.y) }
        for (point, expected) in zip(nine[0].densePoints, rotatedSix) {
            #expect(hypot(point.x - expected.x, point.y - expected.y) < 1.5, "9 strays from the 6 at \(point)")
        }
    }

    @Test("Letter and digit stroke tables never share a key")
    func strokeTablesDontCollide() {
        let shared = Set(LetterTracePathContent.paths.keys).intersection(NumberTracePathContent.paths.keys)
        #expect(shared.isEmpty)
    }

    // MARK: - Tracing

    @Test("Every letter and digit can be traced to completion by following its strokes",
          arguments: TraceKind.allCases)
    func everyItemCanBeCompleted(kind: TraceKind) throws {
        let (context, child) = try makeTestContext()
        let trace = makeTrace(kind, context: context, child: child)
        trace.onAppear()

        for _ in kind.items {
            let id = trace.currentItem?.id ?? "?"
            try traceCurrentItem(trace)
            #expect(trace.isComplete, "\(id) couldn't be finished")
            trace.next()
        }
    }

    @Test("Back from 0 wraps to 9, and forward from 9 wraps to 0")
    func pagingWraps() throws {
        let (context, child) = try makeTestContext()
        let trace = makeTrace(.numbers, context: context, child: child)

        #expect(trace.currentItem?.id == "0")
        trace.previous()
        #expect(trace.currentItem?.id == "9")
        trace.next()
        #expect(trace.currentItem?.id == "0")
    }

    @Test("A digit is prompted and praised with the number clips")
    func digitLinesAreRecorded() async throws {
        let (context, child) = try makeTestContext()
        let speech = HeldSpeech()
        let trace = makeTrace(.numbers, context: context, child: child, speech: speech)

        trace.onAppear()
        trace.next()
        #expect(speech.clips.last == ["trace-prompt-number-1"])

        try traceCurrentItem(trace)
        try await waitUntil { speech.clips.count == 3 }
        #expect(speech.clips.last?.last == "number-thats-1")
        speech.finishAll()
    }

    // MARK: - Progress

    @Test("A traced digit is recorded under the digit, counted on the dashboard, and kept out of the letter trophies")
    func digitProgressIsSeparateFromLetters() throws {
        let (context, child) = try makeTestContext()
        let service = ProgressService(context: context)

        for _ in 0..<6 { service.recordTrace(child: child, letterID: "3", completed: true) }

        #expect(child.traceProgress(for: "3")?.mastery == .mastered)
        #expect(child.masteredTraceCount == 0, "the tracing trophies count letters")

        let dashboard = ParentDashboardViewModel(child: child,
                                                 sessionTimer: SessionTimerService(context: context))
        #expect(dashboard.numberTraceSummary.masteredCount == 1)
        #expect(dashboard.numberTraceSummary.cells.count == 10)
        #expect(dashboard.traceSummary.masteredCount == 0)
    }
}
