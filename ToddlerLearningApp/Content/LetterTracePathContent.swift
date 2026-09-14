//
//  LetterTracePathContent.swift
//  ToddlerLearningApp
//
//  Hand-authored stroke data for the 26 uppercase letters, in normalized
//  0...1 coordinates. Each stroke is a sparse list of anchor points — as few
//  as two for a straight line — that TracePathSampler expands into a smooth
//  on-screen curve and a checkpoint sequence. Multi-stroke letters list their
//  strokes in natural handwriting order (e.g. "A" is left leg, right leg,
//  crossbar), since stroke order is exactly what the old glyph-mask approach
//  couldn't check.
//
//  A shared grid keeps every letter's proportions consistent: `left`/`right`
//  mark the letterform's sides, `top`/`base` its cap-height and baseline, and
//  `mid` the waist used by crossbars and bowls.
//

import CoreGraphics

enum LetterTracePathContent {

    private static let left: CGFloat = 0.24
    private static let right: CGFloat = 0.76
    private static let center: CGFloat = 0.50
    private static let top: CGFloat = 0.16
    private static let mid: CGFloat = 0.52
    private static let base: CGFloat = 0.84

    private static func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y)
    }

    /// A right-hand bowl for B/D/P/R: leaves the stem at `startY`, runs out
    /// along the top arm, turns a rounded end reaching `right`, and runs back
    /// along the bottom arm to the stem at `endY`. The arms are flat unless
    /// `startY`/`endY` say otherwise.
    ///
    /// Built as the exact outline — straight arms, an elliptical end — then
    /// re-spaced into evenly spread anchors for `TracePathSampler`'s
    /// Catmull-Rom smoothing to follow. The five-point version this replaces
    /// put a lone anchor further out at the middle of the curve, which the
    /// smoothing turned into a visible wobble, and ran straight diagonals
    /// between the stem and the bulge, which drew wedges rather than bowls.
    private static func bowl(x: CGFloat,
                             topY: CGFloat,
                             bottomY: CGFloat,
                             right: CGFloat,
                             startY: CGFloat? = nil,
                             endY: CGFloat? = nil) -> [CGPoint] {
        let midY = (topY + bottomY) / 2
        let radiusY = (bottomY - topY) / 2
        let radiusX = min(radiusY, right - x)
        // Where the arms stop and the rounded end begins.
        let turnX = right - radiusX

        let roundEnd = stride(from: CGFloat(-90), through: 90, by: 5).map { degrees in
            let angle = degrees * .pi / 180
            return point(turnX + radiusX * cos(angle), midY + radiusY * sin(angle))
        }
        let outline = [point(x, startY ?? topY)] + roundEnd + [point(x, endY ?? bottomY)]
        return TraceOutline.evenlySpaced(outline, spacing: 0.05)
    }

    /// B's two bowls as one continuous stroke, meeting the stem in a point at
    /// the waist — a sharp corner there, not a curve swinging through it.
    ///
    /// The same bowl twice, mirrored about a waist at the letter's exact
    /// middle, so the bottom matches the top. (The waist used to sit at `mid`,
    /// a little below middle, which left the bottom bowl shorter — and it was
    /// drawn wider as well — so its curve came out smaller and stretched.)
    ///
    /// Their inner arms slant into the waist rather than both running flat
    /// along it: flat, the top bowl's way back in and the bottom bowl's way
    /// out would be the same line, and tracing couldn't tell which of the two
    /// a finger there was on.
    private static var bBowls: TraceStroke {
        let waist = (top + base) / 2
        let upper = bowl(x: left, topY: top, bottomY: waist - 0.05, right: 0.64, endY: waist)
        let lower = bowl(x: left, topY: waist + 0.05, bottomY: base, right: 0.64, startY: waist)
        return TraceStroke(upper + lower.dropFirst(), smooth: true, corners: [upper.count - 1])
    }

    /// The round-letter arc shared by C and G.
    private static var roundArc: [CGPoint] {
        [
            point(0.72, 0.26), point(0.56, top), point(0.42, top),
            point(left, 0.30), point(0.20, mid), point(left, 0.74),
            point(0.42, base), point(0.56, base), point(0.72, 0.78)
        ]
    }

    /// The full closed loop shared by O and Q.
    ///
    /// Runs **clockwise** — top, right, down and round — by deliberate choice.
    /// Note this is the opposite hand motion to `roundArc`, which C and G trace
    /// counter-clockwise, so the two curve families teach different directions.
    /// Now that tracing enforces direction, whichever way these are authored is
    /// what a child is taught, so keep that in mind before editing.
    ///
    /// A true oval filling the grid, built the same way as `bowl`: the exact
    /// outline, re-spaced evenly for the smoothing to follow. The twelve
    /// hand-placed anchors it replaces didn't sit on any one oval — some
    /// bulged out, some sat in — so the loop came out lumpy.
    private static var circle: [CGPoint] {
        let radiusX = (right - left) / 2
        let radiusY = (base - top) / 2
        let centerY = (top + base) / 2
        // -90° is the top; increasing angle runs clockwise on screen (y down).
        let outline = stride(from: CGFloat(-90), through: 270, by: 5).map { degrees in
            let angle = degrees * .pi / 180
            return point(center + radiusX * cos(angle), centerY + radiusY * sin(angle))
        }
        return TraceOutline.evenlySpaced(outline, spacing: 0.05)
    }

    static let paths: [String: LetterTracePath] = [
        "A": LetterTracePath(strokes: [
            TraceStroke([point(center, top), point(left, base)]),
            TraceStroke([point(center, top), point(right, base)]),
            TraceStroke([point(0.32, 0.64), point(0.68, 0.64)])
        ]),
        "B": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            bBowls
        ]),
        "C": LetterTracePath(strokes: [
            TraceStroke(roundArc, smooth: true)
        ]),
        "D": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke(bowl(x: left, topY: top, bottomY: base, right: 0.74), smooth: true)
        ]),
        "E": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke([point(left, top), point(right, top)]),
            TraceStroke([point(left, mid), point(0.66, mid)]),
            TraceStroke([point(left, base), point(right, base)])
        ]),
        "F": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke([point(left, top), point(right, top)]),
            TraceStroke([point(left, mid), point(0.66, mid)])
        ]),
        "G": LetterTracePath(strokes: [
            TraceStroke(
                roundArc + [point(0.72, 0.58), point(0.54, 0.58)],
                smooth: true
            )
        ]),
        "H": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke([point(right, top), point(right, base)]),
            TraceStroke([point(left, mid), point(right, mid)])
        ]),
        "I": LetterTracePath(strokes: [
            TraceStroke([point(center, top), point(center, base)])
        ]),
        "J": LetterTracePath(strokes: [
            TraceStroke([
                point(0.62, top), point(0.62, 0.62), point(0.58, 0.78),
                point(0.46, base), point(0.34, base), point(0.24, 0.76)
            ], smooth: true)
        ]),
        "K": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke([point(right, top), point(left, mid)]),
            TraceStroke([point(left, mid), point(right, base)])
        ]),
        "L": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base), point(right, base)])
        ]),
        // Starts at the top-left, like every other stem in this set. It was
        // authored from the baseline upwards, which no handwriting curriculum
        // teaches and which now that direction is enforced would have children
        // pushing up into the first stroke instead of pulling down.
        "M": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke([
                point(left, top), point(center, 0.58), point(right, top), point(right, base)
            ])
        ]),
        // Pull the left stem down, then the diagonal down to the baseline, then
        // the right stem **upwards** — the diagonal leaves the pen at the
        // bottom right, so carrying on up from there is the continuous motion a
        // hand actually makes. Drawing that last stem top-down would mean
        // lifting back over the letter first.
        "N": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke([point(left, top), point(right, base)]),
            TraceStroke([point(right, base), point(right, top)])
        ]),
        "O": LetterTracePath(strokes: [
            TraceStroke(circle, smooth: true)
        ]),
        "P": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke(bowl(x: left, topY: top, bottomY: mid, right: 0.66), smooth: true)
        ]),
        "Q": LetterTracePath(strokes: [
            TraceStroke(circle, smooth: true),
            TraceStroke([point(0.58, 0.66), point(0.78, 0.90)])
        ]),
        "R": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke(bowl(x: left, topY: top, bottomY: mid, right: 0.66), smooth: true),
            TraceStroke([point(0.50, mid), point(right, base)])
        ]),
        "S": LetterTracePath(strokes: [
            TraceStroke([
                point(0.70, 0.24), point(0.54, top), point(0.38, 0.18), point(0.24, 0.28),
                point(0.30, 0.40), point(0.48, mid), point(0.62, 0.60),
                point(0.68, 0.70), point(0.60, 0.80), point(0.42, base), point(0.24, 0.78)
            ], smooth: true)
        ]),
        "T": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(right, top)]),
            TraceStroke([point(center, top), point(center, base)])
        ]),
        "U": LetterTracePath(strokes: [
            TraceStroke([
                point(left, top), point(left, 0.60), point(0.30, 0.80),
                point(center, base), point(0.70, 0.80), point(right, 0.60), point(right, top)
            ], smooth: true)
        ]),
        "V": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(center, base), point(right, top)])
        ]),
        "W": LetterTracePath(strokes: [
            TraceStroke([
                point(left, top), point(0.38, base), point(center, 0.56), point(0.62, base), point(right, top)
            ])
        ]),
        "X": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(right, base)]),
            TraceStroke([point(right, top), point(left, base)])
        ]),
        "Y": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(center, mid)]),
            TraceStroke([point(right, top), point(center, mid), point(center, base)])
        ]),
        "Z": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(right, top), point(left, base), point(right, base)])
        ])
    ]
}
