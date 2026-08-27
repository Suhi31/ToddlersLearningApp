//
//  QuizLayoutMetrics.swift
//  ToddlerLearningApp
//
//  Both quiz screens size their prompt and answer tiles against the height
//  actually available rather than against fixed point sizes. At fixed sizes
//  the prompt card plus a three-row option grid ran off the bottom of every
//  iPhone in portrait, and neither screen has a scroll view to rescue it —
//  nor should it lean on one, since a toddler will not scroll to look for the
//  answers. Sizing to fit is the fix; the scroll view added alongside is only
//  a backstop for landscape and the largest Dynamic Type settings.
//

import CoreGraphics

struct QuizLayoutMetrics {

    /// The minimum answer-tile width handed to `GridItem(.adaptive(minimum:))`.
    ///
    /// This is what decides the column count, and with it the number of *rows* —
    /// the dominant term in whether the screen fits at all. At 150 a five-option
    /// question wraps to three rows and overflows; three columns keeps it to two
    /// while still leaving every tile far wider than `AppSpacing.minimumTapTarget`.
    ///
    /// The exact value matters: the narrowest supported inner width is 335pt
    /// (a 375pt phone less `AppSpacing.screen` twice), and three columns there
    /// needs `(335 + 14) / 3 - 14 = 102`. Anything above that silently drops to
    /// two columns on small phones and the overflow returns.
    static let optionMinimumWidth: CGFloat = 100

    /// Gap between answer tiles, both across and down.
    static let optionSpacing: CGFloat = 14

    /// Counting emoji are shown up to ten at a time, so they pack tighter than
    /// answer tiles do. Sized by the same argument as `optionMinimumWidth`:
    /// ten items want five columns on the narrowest phone, and the counting
    /// grid sits inside the card's own horizontal padding, so the budget is
    /// `(303 + 10) / 5 - 10 = 52`.
    static let countingMinimumWidth: CGFloat = 50

    /// Height left for the prompt card and the option grid once the screen
    /// padding, the score bar and the inter-section spacing are spoken for.
    let contentHeight: CGFloat

    let size: CGSize

    /// Regular width — iPad, or a wide split. Raises the ceilings below; the
    /// compact values are unchanged so the phone layout stays exactly as it was.
    let isRegular: Bool

    /// Compact height — a phone in landscape.
    let isShort: Bool

    init(size: CGSize, isRegular: Bool, isShort: Bool = false) {
        self.isShort = isShort
        let chrome = AppSpacing.screen * 2       // top + bottom screen padding
            + Self.scoreBarHeight
            + AppSpacing.section * 2             // scoreBar -> prompt -> options
        self.contentHeight = max(size.height - chrome, Self.minimumContentHeight)
        self.size = size
        self.isRegular = isRegular
    }

    // MARK: - Column counts

    /// How many columns to lay `itemCount` items out in.
    ///
    /// `GridItem(.adaptive(minimum:))` creates as many columns as *fit* and
    /// then fills them left to right, so when there are fewer items than
    /// columns the row hangs to the left against a dead gap — on iPad the five
    /// answer tiles filled five of about eight slots and the right-hand third
    /// of the screen sat empty. Capping the column count at the item count and
    /// using `.flexible()` makes the tiles stretch and the row centre instead.
    func columnCount(for itemCount: Int,
                     minimumWidth: CGFloat,
                     spacing: CGFloat,
                     horizontalInset: CGFloat = 0) -> Int {
        let usable = size.width - AppSpacing.screen * 2 - horizontalInset
        let fitting = Int((usable + spacing) / (minimumWidth + spacing))
        return max(1, min(fitting, max(itemCount, 1)))
    }

    /// The hero emoji on the letter quiz. Clamped at the top so it doesn't
    /// become absurd on iPad, and at the bottom so it stays the unmistakable
    /// focal point of the screen on the smallest phone.
    var promptEmojiSize: CGFloat {
        // Hard ceiling on a short screen: the prompt shares the height with the
        // score bar and, side by side, with the answer tiles.
        if isShort { return Self.clamp(contentHeight * 0.24, 56, 120) }
        return Self.clamp(contentHeight * 0.24, 72, isRegular ? 320 : 190)
    }

    /// One repeated emoji on the counting prompt.
    var countingEmojiSize: CGFloat {
        if isShort { return Self.clamp(contentHeight * 0.09, 26, 44) }
        return Self.clamp(contentHeight * 0.09, 34, isRegular ? 120 : 72)
    }

    /// One answer tile's height. The floor sits well above
    /// `AppSpacing.minimumTapTarget` — these are the primary targets on the screen.
    var optionTileHeight: CGFloat {
        // Two rows of tiles have to fit in ~330pt alongside everything else.
        if isShort { return Self.clamp(contentHeight * 0.17, 64, 96) }
        return Self.clamp(contentHeight * 0.17, 88, isRegular ? 240 : 150)
    }

    /// The numeral inside an answer tile, sized off the tile so the two can't
    /// drift apart.
    var optionLabelSize: CGFloat { optionTileHeight * 0.56 }

    private static let scoreBarHeight: CGFloat = 22

    /// Floor for `contentHeight`, so a transiently tiny geometry (during a
    /// push transition, or a zero-height first layout pass) can't collapse
    /// every derived size to its minimum and cause a visible re-jump.
    private static let minimumContentHeight: CGFloat = 320

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
