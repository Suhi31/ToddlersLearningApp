//
//  AppFonts.swift
//  ToddlerLearningApp
//

import SwiftUI

/// Rounded, high-weight type throughout — it reads as friendly to parents and
/// keeps letterforms legible for pre-readers.
///
/// Every **text** style here is built on a `Font.TextStyle` rather than a fixed
/// point size, so it responds to the reader's Dynamic Type setting. A bare
/// `.system(size: 11)` does not scale at all, which left the parent dashboard's
/// legends and chart labels stuck at 10–11pt with no way to enlarge them.
///
/// The **display** sizes at the bottom are deliberately *not* scaled: they are
/// single glyphs already far above any legibility threshold, sized to fill a
/// fixed tile or canvas, and growing them would burst those containers without
/// making anything more readable. Child-facing game screens additionally cap
/// how far Dynamic Type may push text — see `View.childScreenTypeSize()`.
enum AppFonts {

    // MARK: - Text (scales with Dynamic Type)

    /// Screen titles. Base 34pt.
    static let hero = Font.system(.largeTitle, design: .rounded).weight(.heavy)

    /// Section and card headings. Base 22pt.
    static let heading = Font.system(.title2, design: .rounded).weight(.bold)

    /// Primary button text. Base 20pt.
    static let button = Font.system(.title3, design: .rounded).weight(.bold)

    /// Body copy. Base 17pt.
    static let body = Font.system(.body, design: .rounded).weight(.medium)

    /// Secondary copy. Base 15pt.
    static let caption = Font.system(.subheadline, design: .rounded).weight(.medium)

    /// Tile captions such as a trophy's name. Base 12pt.
    static let tileTitle = Font.system(.caption, design: .rounded).weight(.bold)

    /// The smallest labels in the app — dashboard legends, chart weekdays,
    /// eyebrow text. Base 11pt, and now actually enlargeable.
    static let label = Font.system(.caption2, design: .rounded).weight(.medium)

    /// Bold variant of `label`, for eyebrow text like "LETTER OF THE DAY".
    static let labelBold = Font.system(.caption2, design: .rounded).weight(.bold)

    // MARK: - Display (fixed by design — see the type note above)

    /// The giant single letter on the learn screen.
    static let letterHero = Font.system(size: 150, weight: .heavy, design: .rounded)

    /// Letter shown inside a grid tile.
    static let letterTile = Font.system(size: 34, weight: .heavy, design: .rounded)
}

extension View {

    /// Caps Dynamic Type growth on the child-facing game screens.
    ///
    /// Those layouts are grids of fixed-height tiles and a finger-traceable
    /// canvas; past roughly `.accessibility1` the labels stop fitting and the
    /// games become unusable rather than more readable. The text on them is a
    /// handful of single letters and numerals that are already enormous.
    ///
    /// Deliberately **not** applied to the parent screens (dashboard, settings,
    /// onboarding), which are dense prose a parent may genuinely need at the
    /// largest sizes and which scroll freely.
    func childScreenTypeSize() -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}
