//
//  TraceOutline.swift
//  ToddlerLearningApp
//
//  Building blocks for authoring curved strokes, shared by the letter and
//  digit stroke tables. Both build a curve the same way: trace the exact
//  outline — straight runs, elliptical arcs — then re-space it into evenly
//  spread anchors for `TracePathSampler`'s Catmull-Rom smoothing to follow.
//

import CoreGraphics

enum TraceOutline {

    /// Points along an ellipse from `startDegrees` to `endDegrees`, every 5°.
    ///
    /// 0° is the right-hand side and -90° the top. The y axis points down, so
    /// an increasing angle runs **clockwise** on screen and a decreasing one
    /// counter-clockwise — pass `endDegrees` below `startDegrees` for the
    /// latter.
    static func arc(centerX: CGFloat,
                    centerY: CGFloat,
                    radiusX: CGFloat,
                    radiusY: CGFloat,
                    from startDegrees: CGFloat,
                    to endDegrees: CGFloat) -> [CGPoint] {
        let step: CGFloat = endDegrees >= startDegrees ? 5 : -5
        return stride(from: startDegrees, through: endDegrees, by: step).map { degrees in
            let angle = degrees * .pi / 180
            return CGPoint(x: centerX + radiusX * cos(angle), y: centerY + radiusY * sin(angle))
        }
    }

    /// `polyline` re-spaced into anchors an even `spacing` apart, ends kept
    /// exact. Catmull-Rom only follows a shape faithfully when its anchors are
    /// roughly evenly spread: sparse anchors on a straight arm next to dense
    /// ones round a curve make it overshoot into bumps where the two meet.
    static func evenlySpaced(_ polyline: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        var lengths: [CGFloat] = [0]
        for (from, to) in zip(polyline, polyline.dropFirst()) {
            lengths.append(lengths[lengths.count - 1] + hypot(to.x - from.x, to.y - from.y))
        }
        guard let total = lengths.last, total > 0 else { return polyline }

        let count = max(Int((total / spacing).rounded()), 2)
        var segment = 0
        return (0...count).map { step in
            let target = total * CGFloat(step) / CGFloat(count)
            while segment < polyline.count - 2, lengths[segment + 1] < target {
                segment += 1
            }
            let from = polyline[segment]
            let to = polyline[segment + 1]
            let span = lengths[segment + 1] - lengths[segment]
            let t = span > 0 ? (target - lengths[segment]) / span : 0
            return CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        }
    }
}
