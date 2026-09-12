//
//  TraceLetterTests.swift
//  ToddlerLearningAppTests
//
//  The shape of the bowled letters' strokes — which is also the ink a child
//  sees once they've traced them — and paging between letters.
//

import CoreGraphics
import SwiftData
import Testing

@testable import ToddlerLearningApp

@MainActor
struct TraceLetterTests {

    // MARK: - Bowl shape

    /// The bowl stroke (after the stem) has to head steadily down the letter
    /// and change horizontal direction only where the bowl genuinely turns:
    /// once round its far end — plus, for B, back out at the waist and round
    /// the second bowl. The old bowls wobbled in and out at the far end, which
    /// shows up here as extra turns.
    @Test("Bowls curve round cleanly, with no wobble",
          arguments: [("B", 3), ("D", 1), ("P", 1), ("R", 1)])
    func bowlsHaveNoWobble(letterID: String, expectedTurns: Int) throws {
        let geometry = try #require(TracePathSampler.geometry(for: letterID, canvasSize: 320))
        let points = geometry.strokes[1].densePoints
        let steps = Array(zip(points, points.dropFirst()))

        // Against the lowest point reached so far, not just the previous one:
        // a bump spread over several small steps must still count.
        var lowest = -CGFloat.infinity
        for point in points {
            #expect(point.y >= lowest - 0.5, "\(letterID) climbs back up at \(point)")
            lowest = max(lowest, point.y)
        }

        var turns = 0
        var previousDirection = 0
        for (from, to) in steps {
            let dx = to.x - from.x
            guard abs(dx) > 0.05 else { continue }
            let direction = dx > 0 ? 1 : -1
            if previousDirection != 0, direction != previousDirection { turns += 1 }
            previousDirection = direction
        }
        #expect(turns == expectedTurns, "\(letterID)")
    }

    @Test("B's two bowls are the same size")
    func bBowlsMatch() throws {
        let canvas: CGFloat = 320
        let geometry = try #require(TracePathSampler.geometry(for: "B", canvasSize: canvas))
        let points = geometry.strokes[1].densePoints
        // The stroke starts and ends on the stem too, so skip its ends: of
        // what's left, only the waist comes back to touch the stem.
        let waist = try #require(points.dropFirst().dropLast().min { $0.x < $1.x }).y

        let upper = points.filter { $0.y < waist }
        let lower = points.filter { $0.y > waist }
        let upperTop = try #require(upper.map(\.y).min())
        let lowerBottom = try #require(lower.map(\.y).max())
        let upperWidth = try #require(upper.map(\.x).max())
        let lowerWidth = try #require(lower.map(\.x).max())
        let upperHeight = waist - upperTop
        let lowerHeight = lowerBottom - waist

        #expect(abs(upperHeight - lowerHeight) < 1, "heights \(upperHeight) vs \(lowerHeight)")
        #expect(abs(upperWidth - lowerWidth) < 1, "widths \(upperWidth) vs \(lowerWidth)")
    }

    /// Every point of the loop has to sit on one oval — the old hand-placed
    /// anchors bulged in and out of it, which is what made the loop lumpy.
    @Test("O and Q's loop is a true oval", arguments: ["O", "Q"])
    func loopIsOval(letterID: String) throws {
        let canvas: CGFloat = 320
        let geometry = try #require(TracePathSampler.geometry(for: letterID, canvasSize: canvas))
        let points = geometry.strokes[0].densePoints

        let minX = try #require(points.map(\.x).min()), maxX = try #require(points.map(\.x).max())
        let minY = try #require(points.map(\.y).min()), maxY = try #require(points.map(\.y).max())
        let center = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let radiusX = (maxX - minX) / 2, radiusY = (maxY - minY) / 2

        for point in points {
            let dx = (point.x - center.x) / radiusX
            let dy = (point.y - center.y) / radiusY
            #expect(abs(dx * dx + dy * dy - 1) < 0.02, "\(letterID) strays off the oval at \(point)")
        }
    }

    // MARK: - Paging

    @Test("Back from A wraps to Z, and forward from Z wraps to A")
    func pagingWraps() throws {
        let (context, child) = try makeTestContext()
        let trace = TraceLetterViewModel(child: child,
                                         speechService: SilentSpeech(),
                                         rewardService: RewardService(context: context),
                                         progressService: ProgressService(context: context),
                                         haptics: HapticsService())

        #expect(trace.currentLetter?.id == "A")
        #expect(trace.canGoBack)

        trace.previous()
        #expect(trace.currentLetter?.id == "Z")
        #expect(trace.canGoForward)

        trace.next()
        #expect(trace.currentLetter?.id == "A")
    }
}
