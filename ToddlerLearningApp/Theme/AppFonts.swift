//
//  AppFonts.swift
//  ToddlerLearningApp
//

import SwiftUI

/// Rounded, high-weight type throughout — it reads as friendly to parents and
/// keeps letterforms legible for pre-readers.
enum AppFonts {

    static let hero = Font.system(size: 34, weight: .heavy, design: .rounded)
    static let heading = Font.system(size: 22, weight: .bold, design: .rounded)
    static let body = Font.system(size: 17, weight: .medium, design: .rounded)
    static let caption = Font.system(size: 14, weight: .medium, design: .rounded)
    static let button = Font.system(size: 20, weight: .bold, design: .rounded)

    /// The giant single letter on the learn screen.
    static let letterHero = Font.system(size: 150, weight: .heavy, design: .rounded)

    /// Letter shown inside a grid tile.
    static let letterTile = Font.system(size: 34, weight: .heavy, design: .rounded)
}
