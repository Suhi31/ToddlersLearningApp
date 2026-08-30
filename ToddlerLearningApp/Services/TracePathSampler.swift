//
//  TracePathSampler.swift
//  ToddlerLearningApp
//
//  Turns a letter's sparse hand-authored anchor points (LetterTracePathContent)
//  into on-screen geometry, computed once per letter and cached — the
//  replacement for the old LetterMaskService, which paid for an
//  ImageRenderer + CGContext rasterization on first visit to every letter.
//  A few dozen point-arithmetic operations here costs nothing by comparison,
//  so no async/prefetch dance is needed to avoid a hitch.
//

import SwiftUI

/// One stroke's on-screen geometry: a smooth path to draw as the dotted guide,
/// plus the ordered polyline and its arc-length/tangent tables, which is what
/// lets tracing be validated as *progress along* the stroke rather than as a
/// set of checkpoints that happen to get touched.
struct TraceStrokeGeometry {

    let guidePath: Path

    /// The stroke as an ordered polyline, in writing order.
    let densePoints: [CGPoint]

    /// Arc length from the stroke's start to each dense point. Same length as
    /// `densePoints`, monotonically increasing.
    let cumulativeLengths: [CGFloat]

    /// Unit direction of travel at each dense point — the "which way should the
    /// finger be moving" reference.
    let tangents: [CGVector]

    /// Arrowheads along the stroke showing which way to travel, spaced every
    /// `TracePathSampler.directionMarkerSpacing` points of arc length. Built
    /// once alongside the rest of this geometry (see `TracePathSampler`)
    /// instead of being recomputed from a `Canvas` render closure on every
    /// touch point at 60 Hz.
    let directionMarkers: [(point: CGPoint, tangent: CGVector)]

    var totalLength: CGFloat { cumulativeLengths.last ?? 0 }

    var start: CGPoint? { densePoints.first }

    /// The point at `arcLength` along the stroke, for placing the target
    /// chevron, the resume marker and the demo dot.
    func point(atArcLength arcLength: CGFloat) -> CGPoint? {
        guard let index = index(atArcLength: arcLength) else { return nil }
        return densePoints[index]
    }

    func tangent(atArcLength arcLength: CGFloat) -> CGVector? {
        guard let index = index(atArcLength: arcLength) else { return nil }
        return tangents[index]
    }

    /// Binary search for the first point whose cumulative arc length is at
    /// least `arcLength` — equivalent to (and replaces) a linear
    /// `firstIndex { $0 >= clamped }` scan. `cumulativeLengths` is
    /// non-decreasing by construction, which is exactly what a lower-bound
    /// binary search requires: it returns the same index a linear scan would,
    /// including the first index of any run of equal values produced by
    /// coincident dense points. `clamped` never exceeds `totalLength` (the
    /// array's last value), so the search always lands on a valid index —
    /// the `?? densePoints.count - 1` fallback the old linear version needed
    /// was already unreachable.
    private func index(atArcLength arcLength: CGFloat) -> Int? {
        guard !densePoints.isEmpty else { return nil }
        let clamped = min(max(arcLength, 0), totalLength)

        var low = 0
        var high = cumulativeLengths.count - 1
        while low < high {
            let mid = low + (high - low) / 2
            if cumulativeLengths[mid] < clamped {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    /// Projects `point` onto the stroke, but only over `window` of arc length.
    ///
    /// The window is what stops a finger hovering over a *different part of the
    /// same letter* from counting: the previous implementation took the global
    /// minimum distance to the whole stroke, which on a curved letter made the
    /// tolerance corridor the entire shape and let a child circle their way to
    /// completion.
    func project(_ point: CGPoint, within window: ClosedRange<CGFloat>)
        -> (arcLength: CGFloat, distance: CGFloat, tangent: CGVector)? {

        var best: (arcLength: CGFloat, distance: CGFloat, tangent: CGVector)?

        for (index, candidate) in densePoints.enumerated() {
            let arcLength = cumulativeLengths[index]
            guard window.contains(arcLength) else { continue }

            let distance = hypot(candidate.x - point.x, candidate.y - point.y)
            if best == nil || distance < best!.distance {
                best = (arcLength, distance, tangents[index])
            }
        }
        return best
    }
}

struct LetterTraceGeometry {
    let strokes: [TraceStrokeGeometry]

    /// Every stroke's dotted guide path, precomputed alongside `strokes`
    /// instead of `strokes.map(\.guidePath)` being re-run on every read —
    /// this is fetched from two separate `Canvas` render closures per frame.
    let guidePaths: [Path]
}

@MainActor
enum TracePathSampler {

    /// Interpolated points per authored segment — enough that a smoothed
    /// curve reads as round rather than faceted at the sizes this app draws.
    private static let samplesPerSegment = 14

    /// Spacing between direction-arrow markers, in points of arc length.
    /// Matches the one spacing `TraceLetterView` ever actually asked for.
    private static let directionMarkerSpacing: CGFloat = 64

    private struct CacheKey: Hashable {
        let letterID: String
        let canvasSize: CGFloat
    }

    private static var cache: [CacheKey: LetterTraceGeometry] = [:]

    static func geometry(for letterID: String, canvasSize: CGFloat) -> LetterTraceGeometry? {
        let key = CacheKey(letterID: letterID, canvasSize: canvasSize)
        if let cached = cache[key] { return cached }
        guard let path = LetterTracePathContent.paths[letterID] else { return nil }

        let strokes = path.strokes.map { geometry(for: $0, canvasSize: canvasSize) }
        let built = LetterTraceGeometry(strokes: strokes, guidePaths: strokes.map(\.guidePath))
        cache[key] = built
        return built
    }

    private static func geometry(for stroke: TraceStroke, canvasSize: CGFloat) -> TraceStrokeGeometry {
        let scaled = stroke.points.map { CGPoint(x: $0.x * canvasSize, y: $0.y * canvasSize) }
        let dense = stroke.smooth
            ? catmullRom(scaled, samplesPerSegment: samplesPerSegment)
            : piecewiseLinear(scaled, samplesPerSegment: samplesPerSegment)

        var guidePath = Path()
        if let first = dense.first {
            guidePath.move(to: first)
            for p in dense.dropFirst() { guidePath.addLine(to: p) }
        }

        let cumulativeLengths = cumulativeLengths(of: dense)
        let tangents = tangents(of: dense)

        return TraceStrokeGeometry(
            guidePath: guidePath,
            densePoints: dense,
            cumulativeLengths: cumulativeLengths,
            tangents: tangents,
            directionMarkers: directionMarkers(
                densePoints: dense,
                cumulativeLengths: cumulativeLengths,
                tangents: tangents,
                spacing: directionMarkerSpacing
            )
        )
    }

    /// Arrowheads spaced every `spacing` points of arc length along a stroke,
    /// starting half a spacing in so a marker never sits on top of the start
    /// badge or the very end of the stroke. Reads the dense/length/tangent
    /// arrays directly rather than through `TraceStrokeGeometry`'s
    /// `point(atArcLength:)`/`tangent(atArcLength:)` — this runs once at
    /// geometry-build time, before there is a `TraceStrokeGeometry` to call
    /// those methods on.
    private static func directionMarkers(
        densePoints: [CGPoint],
        cumulativeLengths: [CGFloat],
        tangents: [CGVector],
        spacing: CGFloat
    ) -> [(point: CGPoint, tangent: CGVector)] {
        let totalLength = cumulativeLengths.last ?? 0
        guard totalLength > 0 else { return [] }

        return stride(from: spacing / 2, to: totalLength, by: spacing).compactMap { distance in
            guard let index = cumulativeLengths.firstIndex(where: { $0 >= distance }) else { return nil }
            return (densePoints[index], tangents[index])
        }
    }

    // MARK: - Straight segments

    /// Angular letters (L, M, V, Z, ...) need their corners to stay sharp, so
    /// each consecutive pair of anchors is interpolated independently rather
    /// than smoothed through as one curve.
    private static func piecewiseLinear(_ points: [CGPoint], samplesPerSegment: Int) -> [CGPoint] {
        guard points.count > 1 else { return points }
        var dense = [points[0]]
        for index in 1..<points.count {
            dense.append(contentsOf: linearSegment(points[index - 1], points[index], samplesPerSegment: samplesPerSegment).dropFirst())
        }
        return dense
    }

    private static func linearSegment(_ start: CGPoint, _ end: CGPoint, samplesPerSegment: Int) -> [CGPoint] {
        (0...samplesPerSegment).map { step in
            let t = CGFloat(step) / CGFloat(samplesPerSegment)
            return CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
        }
    }

    // MARK: - Smoothed curves

    /// Clamped Catmull-Rom through the authored anchors — duplicating the
    /// first/last anchor as its own virtual neighbor keeps the curve starting
    /// and ending exactly on the authored points instead of overshooting.
    private static func catmullRom(_ points: [CGPoint], samplesPerSegment: Int) -> [CGPoint] {
        guard points.count > 2 else {
            guard let first = points.first, let last = points.last else { return points }
            return linearSegment(first, last, samplesPerSegment: samplesPerSegment)
        }

        var dense: [CGPoint] = []
        let extended = [points[0]] + points + [points[points.count - 1]]

        for i in 1..<(extended.count - 2) {
            let p0 = extended[i - 1]
            let p1 = extended[i]
            let p2 = extended[i + 1]
            let p3 = extended[i + 2]

            for step in 0..<samplesPerSegment {
                let t = CGFloat(step) / CGFloat(samplesPerSegment)
                dense.append(catmullRomPoint(p0, p1, p2, p3, t))
            }
        }
        dense.append(points[points.count - 1])
        return dense
    }

    private static func catmullRomPoint(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t

        func component(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            0.5 * ((2 * b)
                + (-a + c) * t
                + (2 * a - 5 * b + 4 * c - d) * t2
                + (-a + 3 * b - 3 * c + d) * t3)
        }

        return CGPoint(
            x: component(p0.x, p1.x, p2.x, p3.x),
            y: component(p0.y, p1.y, p2.y, p3.y)
        )
    }

    // MARK: - Arc length and tangents

    /// Running arc length at each point. This is the same walk the old
    /// checkpoint resampler did; it just keeps every step instead of dropping a
    /// marker every 40pt.
    private static func cumulativeLengths(of dense: [CGPoint]) -> [CGFloat] {
        guard !dense.isEmpty else { return [] }

        var lengths: [CGFloat] = [0]
        lengths.reserveCapacity(dense.count)

        for index in 1..<dense.count {
            let step = hypot(dense[index].x - dense[index - 1].x,
                             dense[index].y - dense[index - 1].y)
            lengths.append(lengths[index - 1] + step)
        }
        return lengths
    }

    /// Unit direction of travel at each point, from a central difference so
    /// corners get the average of the two adjacent segments rather than
    /// whichever one happens to come first.
    private static func tangents(of dense: [CGPoint]) -> [CGVector] {
        guard dense.count > 1 else { return dense.map { _ in CGVector(dx: 0, dy: 0) } }

        return dense.indices.map { index in
            let previous = dense[max(index - 1, 0)]
            let next = dense[min(index + 1, dense.count - 1)]
            return normalized(CGVector(dx: next.x - previous.x, dy: next.y - previous.y))
        }
    }

    private static func normalized(_ vector: CGVector) -> CGVector {
        let magnitude = hypot(vector.dx, vector.dy)
        guard magnitude > 0 else { return CGVector(dx: 0, dy: 0) }
        return CGVector(dx: vector.dx / magnitude, dy: vector.dy / magnitude)
    }
}
