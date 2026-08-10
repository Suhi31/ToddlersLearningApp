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

/// One stroke's on-screen geometry: a smooth path to draw as the dotted
/// guide, a dense point list to measure deviation against, and the ordered
/// checkpoints a trace must pass through to complete the stroke.
struct TraceStrokeGeometry {
    let guidePath: Path
    let densePoints: [CGPoint]
    let waypoints: [CGPoint]
}

struct LetterTraceGeometry {
    let strokes: [TraceStrokeGeometry]
}

@MainActor
enum TracePathSampler {

    /// Interpolated points per authored segment — enough that a smoothed
    /// curve reads as round rather than faceted at the sizes this app draws.
    private static let samplesPerSegment = 14

    /// Target spacing between checkpoints, in on-screen points. Wide enough
    /// that a toddler's fingertip comfortably lands inside
    /// `TraceLetterViewModel`'s tolerance radius around each one, tight
    /// enough that a letter isn't reduced to two or three checkpoints total.
    private static let waypointSpacing: CGFloat = 40

    private struct CacheKey: Hashable {
        let letterID: String
        let canvasSize: CGFloat
    }

    private static var cache: [CacheKey: LetterTraceGeometry] = [:]

    static func geometry(for letterID: String, canvasSize: CGFloat) -> LetterTraceGeometry? {
        let key = CacheKey(letterID: letterID, canvasSize: canvasSize)
        if let cached = cache[key] { return cached }
        guard let path = LetterTracePathContent.paths[letterID] else { return nil }

        let built = LetterTraceGeometry(strokes: path.strokes.map { geometry(for: $0, canvasSize: canvasSize) })
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

        return TraceStrokeGeometry(
            guidePath: guidePath,
            densePoints: dense,
            waypoints: resample(dense, spacing: waypointSpacing)
        )
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

    // MARK: - Waypoint resampling

    /// Walks the dense polyline and drops a checkpoint every `spacing` points
    /// of arc length, always including the final point so the last checkpoint
    /// lands exactly at the stroke's end.
    private static func resample(_ dense: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard let first = dense.first else { return [] }
        var waypoints = [first]
        var accumulated: CGFloat = 0

        for index in 1..<dense.count {
            let previous = dense[index - 1]
            let current = dense[index]
            accumulated += hypot(current.x - previous.x, current.y - previous.y)
            if accumulated >= spacing {
                waypoints.append(current)
                accumulated = 0
            }
        }

        if let last = dense.last, waypoints.last != last {
            waypoints.append(last)
        }
        return waypoints
    }
}
