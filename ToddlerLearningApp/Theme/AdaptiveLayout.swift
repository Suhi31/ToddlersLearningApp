//
//  AdaptiveLayout.swift
//  ToddlerLearningApp
//
//  The app had no size adaptation at all — every grid used a hardcoded column
//  count and every tile a fixed height, all tuned for a ~390pt phone. On iPad
//  that rendered the phone layout stretched, with content letterboxing across
//  960pt and a third to a half of the screen empty.
//
//  Everything keys off the *horizontal size class* rather than the device
//  idiom, which is what makes landscape and iPad Split View fall out of the
//  same code: a third-width iPad app reports compact and correctly gets the
//  phone layout back.
//

import SwiftUI

struct AdaptiveLayout {

    /// Regular width — iPad full screen, or a wide enough split.
    let isRegular: Bool

    /// Compact *height* — in practice a phone in landscape, where there is
    /// barely 330pt of usable height. Screens built around a tall column of
    /// content have to rearrange here, not just shrink.
    let isShort: Bool

    let size: CGSize

    init(size: CGSize,
         horizontalSizeClass: UserInterfaceSizeClass?,
         verticalSizeClass: UserInterfaceSizeClass? = nil) {
        self.size = size
        self.isRegular = horizontalSizeClass == .regular
        self.isShort = verticalSizeClass == .compact
    }

    /// Wider than it is tall. Distinct from `isShort`: an iPad in landscape is
    /// wide but not short, and wants a different treatment from a phone.
    var isLandscape: Bool { size.width > size.height }

    /// Cap for fields and buttons. A 960pt-wide "Enter your name" box is the
    /// clearest tell of a stretched phone layout.
    var formWidth: CGFloat { isRegular ? 560 : .infinity }

    /// Cap for paragraphs. 960pt lines are poor measure to read.
    var proseWidth: CGFloat { isRegular ? 720 : .infinity }

    // MARK: - Home activity grid

    /// Minimum tile width, which decides the column count.
    ///
    /// A single 150pt minimum would give six columns on an iPad — eight small
    /// tiles crowded into the top third with the rest of the screen empty.
    /// Asking for a much wider tile yields three roomy columns instead, so the
    /// grid grows into the space rather than multiplying into it.
    var activityTileMinimumWidth: CGFloat { isRegular ? 280 : 150 }

    /// Tall enough that three rows of tiles fill an iPad's height, while the
    /// compact value keeps all eight activities above the fold on a phone.
    var activityTileHeight: CGFloat {
        // A phone in landscape has ~330pt of height; 120pt tiles show barely
        // one row, so they shrink to keep two rows in view.
        if isShort { return 100 }
        return isRegular ? 280 : 120
    }

    // MARK: - Learn screens

    /// The giant single letter or numeral on the Learn stage. A display glyph,
    /// deliberately exempt from Dynamic Type, so it needs its own size-class
    /// branch rather than a text style — 150pt is lost on an iPad.
    var heroGlyphSize: CGFloat { isRegular ? 240 : 150 }

    /// Minimum width for a jump-strip tile. The fixed five columns stretched
    /// each tile to 250x76 on an iPad; asking for a width keeps them squarer
    /// and simply yields more columns as the screen widens.
    var stripTileMinimumWidth: CGFloat { isRegular ? 96 : 60 }
}
