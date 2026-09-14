//
//  TraceTolerances.swift
//  ToddlerLearningApp
//
//  Every tolerance the tracing validator uses, in one place, expressed as a
//  fraction of the canvas edge — the same "ratios, not point values" approach
//  QuizLayoutMetrics and AdaptiveLayout use, so a trace feels equally forgiving
//  on a 280pt phone canvas and an 800pt iPad one.
//
//  The important tuning note: it is the *arc-length window* that makes tracing
//  honest here, not a tight corridor. Narrowing the corridor mostly punishes a
//  two-year-old's unsteady finger; narrowing the window is what stops a child
//  drifting to a different part of the letter, circling, or skipping ahead.
//  Widen `corridor` freely if testing shows frustration; widen `lookAhead` only
//  with care.
//

import CoreGraphics

struct TraceTolerances {

    let canvasSize: CGFloat

    init(canvasSize: CGFloat) {
        self.canvasSize = max(canvasSize, 1)
    }

    /// How far off the stroke a finger may stray and still count. Generous:
    /// this is the one that governs "did my hand wobble", not "am I cheating".
    var corridor: CGFloat { canvasSize * 0.14 }

    /// How far *ahead* of current progress a touch may match. Caps how much of
    /// a stroke can be skipped in one movement — a child who lifts and jumps to
    /// the far end gets no credit for the span they missed.
    var lookAhead: CGFloat { canvasSize * 0.18 }

    /// How far *behind* progress a touch may still match, so a finger that
    /// wobbles backwards over ground it already covered isn't dropped.
    var lookBehind: CGFloat { canvasSize * 0.09 }

    /// How close the first touch of a stroke must be to its start point.
    var startRadius: CGFloat { canvasSize * 0.13 }

    /// After lifting mid-stroke, how close the finger must land to where it
    /// left off. This is what makes tap-tap-tap along the stroke fail while
    /// still forgiving a slipped grip.
    var resumeRadius: CGFloat { canvasSize * 0.13 }

    /// Fraction of the stroke that counts as done, so the last sliver of slop
    /// near the end point doesn't block completion.
    var completionFraction: CGFloat { 0.9 }

    /// Minimum agreement between the finger's movement and the stroke's
    /// direction of travel, as a dot product of unit vectors.
    ///
    /// Zero — "anything not actively backwards" — proved too weak: a child
    /// circling inside the letter still crept forward roughly 4% per loop,
    /// because any loop has a downward component that scrapes past a
    /// greater-than-zero test. At 0.35 the finger has to be travelling within
    /// about 70 degrees of the stroke, which normal wobble clears easily and a
    /// circle does not.
    var directionAgreement: CGFloat { 0.35 }

    /// Movements shorter than this are treated as jitter and skipped for the
    /// direction test — a nearly-stationary finger has no meaningful direction
    /// and would otherwise produce noise.
    var minimumMovement: CGFloat { canvasSize * 0.006 }

    /// A gap between consecutive touch points larger than this is read as the
    /// finger having lifted, regardless of what the gesture reported. Well
    /// above the few points a tracing finger covers between events at 60Hz,
    /// and well below the distance that would let a tap land meaningfully
    /// further along a stroke.
    var liftJump: CGFloat { canvasSize * 0.12 }

    /// Consecutive rejected touches before the direction demo replays. High
    /// enough that a moment's wobble doesn't trigger it.
    static let slipsBeforeReplay = 24

    /// How long a child can go without progress — idle, stuck, or tracing the
    /// wrong way — before the direction demo replays. Counted from the last
    /// progress or the end of the last demo, whichever is later.
    static let hintDelay: Duration = .seconds(3)
}
