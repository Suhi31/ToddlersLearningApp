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

    /// A right-bulging bowl used by B/D/P/R, running from `topY` to `bottomY`
    /// at `x`, bulging out to `bulge`.
    private static func bowl(x: CGFloat, topY: CGFloat, bottomY: CGFloat, bulge: CGFloat) -> [CGPoint] {
        let midY = (topY + bottomY) / 2
        return [
            point(x, topY),
            point(bulge, topY + (midY - topY) * 0.35),
            point(bulge + 0.04, midY),
            point(bulge, midY + (bottomY - midY) * 0.35),
            point(x, bottomY)
        ]
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
    private static var circle: [CGPoint] {
        [
            point(center, top), point(0.64, 0.19), point(0.72, 0.32), point(right, mid),
            point(0.72, 0.72), point(0.64, 0.83), point(center, base),
            point(0.36, 0.83), point(0.28, 0.72), point(left, mid),
            point(0.28, 0.32), point(0.36, 0.19), point(center, top)
        ]
    }

    static let paths: [String: LetterTracePath] = [
        "A": LetterTracePath(strokes: [
            TraceStroke([point(center, top), point(left, base)]),
            TraceStroke([point(center, top), point(right, base)]),
            TraceStroke([point(0.32, 0.64), point(0.68, 0.64)])
        ]),
        "B": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke(
                bowl(x: left, topY: top, bottomY: mid, bulge: 0.64)
                    + bowl(x: left, topY: mid, bottomY: base, bulge: 0.70).dropFirst(),
                smooth: true
            )
        ]),
        "C": LetterTracePath(strokes: [
            TraceStroke(roundArc, smooth: true)
        ]),
        "D": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke(bowl(x: left, topY: top, bottomY: base, bulge: 0.70), smooth: true)
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
        "M": LetterTracePath(strokes: [
            TraceStroke([
                point(left, base), point(left, top),
                point(center, 0.58), point(right, top), point(right, base)
            ])
        ]),
        "N": LetterTracePath(strokes: [
            TraceStroke([point(left, base), point(left, top), point(right, base), point(right, top)])
        ]),
        "O": LetterTracePath(strokes: [
            TraceStroke(circle, smooth: true)
        ]),
        "P": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke(bowl(x: left, topY: top, bottomY: mid, bulge: 0.64), smooth: true)
        ]),
        "Q": LetterTracePath(strokes: [
            TraceStroke(circle, smooth: true),
            TraceStroke([point(0.58, 0.66), point(0.78, 0.90)])
        ]),
        "R": LetterTracePath(strokes: [
            TraceStroke([point(left, top), point(left, base)]),
            TraceStroke(bowl(x: left, topY: top, bottomY: mid, bulge: 0.64), smooth: true),
            TraceStroke([point(0.52, mid), point(right, base)])
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
