//
//  NumberTracePathContent.swift
//  ToddlerLearningApp
//
//  Hand-authored stroke data for the digits 0–9, the Trace Numbers twin of
//  LetterTracePathContent — same normalized 0...1 square, same sparse anchors
//  expanded by TracePathSampler.
//
//  Tracing enforces direction, so whatever is authored here is what a child
//  learns. The directions are deliberate choices:
//
//  - 0 and 9 go **clockwise** — 0 the same way as the letter O (see
//    `LetterTracePathContent.circle`), and 9 as the 6 turned upside down.
//  - 6 goes **counter-clockwise**, and 8 sets off to the left over the top.
//  - 4 is the open, two-stroke 4 — "down and across, then down" — rather than
//    the closed typeface form.
//
//  Change one and you change what is taught; the direction tests in
//  TraceNumberTests pin 0, 6 and 9.
//
//  Digits share the letters' `top` and `base`, so a traced 3 is the same
//  height as a traced B, but sit on a narrower grid: a digit is a slimmer
//  shape than most capitals.
//

import CoreGraphics

enum NumberTracePathContent {

    private static let left: CGFloat = 0.30
    private static let right: CGFloat = 0.70
    private static let center: CGFloat = 0.50
    private static let top: CGFloat = 0.16
    private static let base: CGFloat = 0.84

    private static func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y)
    }

    private static func smoothed(_ outline: [CGPoint]) -> [CGPoint] {
        TraceOutline.evenlySpaced(outline, spacing: 0.05)
    }

    /// An oval filling the grid, clockwise from the top.
    private static var zero: TraceStroke {
        let loop = TraceOutline.arc(centerX: center, centerY: (top + base) / 2,
                                    radiusX: 0.20, radiusY: (base - top) / 2,
                                    from: -90, to: 270)
        return TraceStroke(smoothed(loop), smooth: true)
    }

    /// A curve over the top, a straight neck down to the bottom left, then a
    /// sharp turn along the baseline.
    ///
    /// The arc stops at 40° because that is where its direction lines up with
    /// the neck, so the curve runs into the diagonal without a kink.
    private static var two: TraceStroke {
        let curve = TraceOutline.arc(centerX: center, centerY: 0.34,
                                     radiusX: 0.19, radiusY: 0.18,
                                     from: -160, to: 40)
        let neck = smoothed(curve + [point(left, base)])
        return TraceStroke(neck + [point(0.72, base)], smooth: true, corners: [neck.count - 1])
    }

    /// Two bumps in one stroke. The pen comes back in to the middle and turns
    /// out again, so the waist is a sharp point rather than a curve.
    ///
    /// Each bump meets the waist along a short slanted arm, as B's bowls do,
    /// for the same reason: two round bumps would touch along a stretch there,
    /// and tracing couldn't tell which of the two a finger on it was on.
    private static var three: TraceStroke {
        let waist = point(0.40, 0.49)
        let upper = smoothed(TraceOutline.arc(centerX: 0.49, centerY: 0.3125,
                                              radiusX: 0.18, radiusY: 0.1525,
                                              from: -160, to: 90) + [waist])
        let lower = smoothed([waist] + TraceOutline.arc(centerX: 0.49, centerY: 0.6775,
                                                        radiusX: 0.205, radiusY: 0.1625,
                                                        from: -90, to: 160))
        return TraceStroke(upper + lower.dropFirst(), smooth: true, corners: [upper.count - 1])
    }

    /// Down the short stem, then round the belly, finishing low on the left.
    /// The flat top is a separate, second stroke.
    ///
    /// The belly's arc starts at -115° because there it is already heading the
    /// way the pen leaves the stem — up and to the right. Started further
    /// round, the join wobbled.
    private static var fiveBody: TraceStroke {
        let stemTop = point(0.34, top)
        let stemBottom = point(0.33, 0.49)
        let belly = TraceOutline.arc(centerX: 0.49, centerY: 0.645,
                                     radiusX: 0.20, radiusY: 0.195,
                                     from: -115, to: 155)
        return TraceStroke([stemTop] + smoothed([stemBottom] + belly), smooth: true, corners: [1])
    }

    /// A long curve down the left side that runs, without a break in
    /// direction, into a counter-clockwise loop at the bottom.
    private static var six: TraceStroke {
        let sweep = TraceOutline.arc(centerX: 0.68, centerY: 0.65,
                                     radiusX: 0.38, radiusY: 0.49,
                                     from: -95, to: -180)
        let loop = TraceOutline.arc(centerX: center, centerY: 0.65,
                                    radiusX: 0.20, radiusY: 0.19,
                                    from: 180, to: -160)
        return TraceStroke(smoothed(sweep + loop.dropFirst()), smooth: true)
    }

    /// A figure of eight in one stroke: left over the top, crossing in the
    /// middle, round the bottom and back up through the crossing.
    ///
    /// A lemniscate rather than two stacked circles, so the pen genuinely
    /// crosses on a diagonal — two circles meet at a tangent, which draws a
    /// snowman. The bottom loop is a little wider and taller than the top one,
    /// as a written 8 is.
    private static var eight: TraceStroke {
        let waist: CGFloat = 0.47
        let outline = stride(from: CGFloat(0), through: 360, by: 5).map { degrees in
            let t = degrees * .pi / 180
            let isUpper = cos(t) >= 0
            let width: CGFloat = isUpper ? 0.17 : 0.21
            let height = isUpper ? waist - top : base - waist
            return point(center - width * sin(2 * t), waist - height * cos(t))
        }
        return TraceStroke(smoothed(outline), smooth: true)
    }

    /// The 6 turned upside down and drawn the other way: a clockwise loop at
    /// the top that runs, without a break in direction, into a long curve down
    /// the right side to the bottom left.
    ///
    /// Every point is `six`'s rotated half a turn about the centre, and the
    /// order reversed so the pen starts in the loop rather than at the tail.
    /// Like the 6, the loop stops short of closing, so the tail sweeps away
    /// from it instead of retracing it — a tail running back over the loop is
    /// a line tracing couldn't tell apart from the loop.
    private static var nine: TraceStroke {
        let loop = TraceOutline.arc(centerX: center, centerY: 0.35,
                                    radiusX: 0.20, radiusY: 0.19,
                                    from: 20, to: 360)
        let sweep = TraceOutline.arc(centerX: 0.32, centerY: 0.35,
                                     radiusX: 0.38, radiusY: 0.49,
                                     from: 0, to: 85)
        return TraceStroke(smoothed(loop + sweep.dropFirst()), smooth: true)
    }

    static let paths: [String: LetterTracePath] = [
        "0": LetterTracePath(strokes: [zero]),
        // A short flag up to the top, then straight down. Without the flag the
        // shape reads as a capital I or a lower-case l.
        "1": LetterTracePath(strokes: [
            TraceStroke([point(0.38, 0.28), point(0.54, top), point(0.54, base)])
        ]),
        "2": LetterTracePath(strokes: [two]),
        "3": LetterTracePath(strokes: [three]),
        "4": LetterTracePath(strokes: [
            TraceStroke([point(0.34, top), point(0.32, 0.60), point(0.74, 0.60)]),
            TraceStroke([point(0.62, top), point(0.62, base)])
        ]),
        "5": LetterTracePath(strokes: [
            fiveBody,
            TraceStroke([point(0.34, top), point(right, top)])
        ]),
        "6": LetterTracePath(strokes: [six]),
        "7": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(right, top), point(0.42, base)])
        ]),
        "8": LetterTracePath(strokes: [eight]),
        "9": LetterTracePath(strokes: [nine])
    ]
}
