//
//  TracePathSamplerTests.swift
//  ToddlerLearningAppTests
//
//  Differential tests for the F15 performance pass: `TraceStrokeGeometry`'s
//  arc-length lookup moved from a linear scan to a binary search, and its
//  direction markers moved from being recomputed on every `Canvas` render
//  pass to being built once alongside the rest of the geometry. Neither
//  change was allowed to alter tracing's behaviour even slightly, so every
//  test here re-implements the *old* algorithm independently and asserts it
//  against the *current* production API, rather than testing the production
//  code against itself.
//

import CoreGraphics
import Testing

@testable import ToddlerLearningApp

@MainActor
struct TracePathSamplerTests {

    /// A handful of sizes spanning the real range `TraceLetterView` asks
    /// for — the floor on a short phone screen, a typical phone canvas, and
    /// the iPad ceiling.
    private static let canvasSizes: [CGFloat] = [120, 200, 320, 500, 800]

    private static let letterIDs = AlphabetContent.letters.map(\.id)

    // MARK: - Reference implementations (the pre-F15 algorithms)

    /// The exact linear scan `TraceStrokeGeometry.index(atArcLength:)` used
    /// before it became a binary search.
    private static func referenceIndex(cumulativeLengths: [CGFloat], arcLength: CGFloat) -> Int? {
        guard !cumulativeLengths.isEmpty else { return nil }
        let totalLength = cumulativeLengths.last ?? 0
        let clamped = min(max(arcLength, 0), totalLength)
        let found = cumulativeLengths.firstIndex { $0 >= clamped }
        return found ?? cumulativeLengths.count - 1
    }

    /// The exact stride-and-lookup `TraceLetterViewModel.directionMarkers(spacing:)`
    /// used before markers moved onto `TraceStrokeGeometry` at build time.
    private static func referenceMarkers(
        densePoints: [CGPoint],
        cumulativeLengths: [CGFloat],
        tangents: [CGVector],
        spacing: CGFloat
    ) -> [(point: CGPoint, tangent: CGVector)] {
        let totalLength = cumulativeLengths.last ?? 0
        guard totalLength > 0 else { return [] }

        return stride(from: spacing / 2, to: totalLength, by: spacing).compactMap { distance in
            guard let index = referenceIndex(cumulativeLengths: cumulativeLengths, arcLength: distance) else {
                return nil
            }
            return (densePoints[index], tangents[index])
        }
    }

    // MARK: - index / point / tangent

    @Test("point(atArcLength:) and tangent(atArcLength:) match a linear-scan reference, across every letter, several canvas sizes, and a full sweep of each stroke")
    func arcLengthLookupMatchesLinearScanReference() throws {
        for letterID in Self.letterIDs {
            for canvasSize in Self.canvasSizes {
                let geometry = try #require(
                    TracePathSampler.geometry(for: letterID, canvasSize: canvasSize),
                    "no geometry for letter \(letterID) at size \(canvasSize)"
                )

                for stroke in geometry.strokes {
                    let total = stroke.totalLength

                    // A fine sweep across the whole stroke, plus the exact
                    // endpoints and a couple of out-of-range values to
                    // exercise the clamping path.
                    var arcLengths: [CGFloat] = [-50, 0, total, total + 50]
                    let steps = 40
                    for step in 0...steps {
                        arcLengths.append(total * CGFloat(step) / CGFloat(steps))
                    }

                    for arcLength in arcLengths {
                        let expectedIndex = Self.referenceIndex(
                            cumulativeLengths: stroke.cumulativeLengths, arcLength: arcLength
                        )
                        let expectedPoint = expectedIndex.map { stroke.densePoints[$0] }
                        let expectedTangent = expectedIndex.map { stroke.tangents[$0] }

                        let actualPoint = stroke.point(atArcLength: arcLength)
                        let actualTangent = stroke.tangent(atArcLength: arcLength)

                        #expect(actualPoint == expectedPoint,
                                "letter \(letterID) size \(canvasSize) arcLength \(arcLength): point mismatch")
                        #expect(actualTangent?.dx == expectedTangent?.dx && actualTangent?.dy == expectedTangent?.dy,
                                "letter \(letterID) size \(canvasSize) arcLength \(arcLength): tangent mismatch")
                    }
                }
            }
        }
    }

    // MARK: - Direction markers

    @Test("directionMarkers matches an independently-computed reference, across every letter and several canvas sizes")
    func directionMarkersMatchReference() throws {
        let spacing: CGFloat = 64

        for letterID in Self.letterIDs {
            for canvasSize in Self.canvasSizes {
                let geometry = try #require(
                    TracePathSampler.geometry(for: letterID, canvasSize: canvasSize),
                    "no geometry for letter \(letterID) at size \(canvasSize)"
                )

                for stroke in geometry.strokes {
                    let expected = Self.referenceMarkers(
                        densePoints: stroke.densePoints,
                        cumulativeLengths: stroke.cumulativeLengths,
                        tangents: stroke.tangents,
                        spacing: spacing
                    )
                    let actual = stroke.directionMarkers

                    #expect(actual.count == expected.count,
                            "letter \(letterID) size \(canvasSize): marker count mismatch")

                    for (actualMarker, expectedMarker) in zip(actual, expected) {
                        #expect(actualMarker.point == expectedMarker.point,
                                "letter \(letterID) size \(canvasSize): marker point mismatch")
                        #expect(actualMarker.tangent.dx == expectedMarker.tangent.dx
                                && actualMarker.tangent.dy == expectedMarker.tangent.dy,
                                "letter \(letterID) size \(canvasSize): marker tangent mismatch")
                    }
                }
            }
        }
    }

    // MARK: - guidePaths

    @Test("guidePaths on LetterTraceGeometry matches strokes.map(\\.guidePath)")
    func guidePathsMatchesPerStrokeGuidePath() throws {
        for letterID in Self.letterIDs {
            let geometry = try #require(TracePathSampler.geometry(for: letterID, canvasSize: 320))
            #expect(geometry.guidePaths.count == geometry.strokes.count)
            for (index, stroke) in geometry.strokes.enumerated() {
                #expect(geometry.guidePaths[index] == stroke.guidePath)
            }
        }
    }
}
