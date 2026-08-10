//
//  LetterTracePath.swift
//  ToddlerLearningApp
//
//  Replaces the old font-rasterized "ink mask" approach (see the deleted
//  LetterMaskService) with hand-authored per-letter pen strokes, validated as
//  an ordered checkpoint sequence rather than coarse region coverage. This is
//  what lets tracing actually check stroke order and reject a scribble.
//

import CoreGraphics

/// One pen stroke of a letter, authored as a handful of anchor points in a
/// normalized 0...1 unit square (top-left origin, y-down — the same
/// convention SwiftUI touch coordinates already use). `TracePathSampler`
/// turns these few anchors into a smooth on-screen curve and a checkpoint
/// sequence; the anchors themselves stay sparse and easy to hand-tune.
struct TraceStroke {
    let points: [CGPoint]

    /// Curved letters (C, O, S, the bowls of B/D/P/R, ...) want their anchors
    /// smoothed into a rounded curve; angular letters (L, M, V, Z, ...) need
    /// their corners to stay sharp. Defaults to sharp/straight since most
    /// strokes are simple two-point lines where this has no effect either way.
    var smooth: Bool = false

    init(_ points: [CGPoint], smooth: Bool = false) {
        self.points = points
        self.smooth = smooth
    }
}

/// A letter's complete pen-stroke sequence, in writing order. Multi-stroke
/// letters (A, B, E, ...) require each stroke's checkpoints to be completed,
/// in order, before the next stroke's checkpoints can register — see
/// `TraceLetterViewModel`.
struct LetterTracePath {
    let strokes: [TraceStroke]
}
