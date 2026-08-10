//
//  AppColors.swift
//  ToddlerLearningApp
//

import SwiftUI

enum AppColors {

    // MARK: - Surfaces

    static let backgroundTop = Color(red: 0.99, green: 0.96, blue: 1.00)
    static let backgroundBottom = Color(red: 0.90, green: 0.96, blue: 1.00)
    static let card = Color.white

    // MARK: - Text

    static let title = Color(red: 0.16, green: 0.15, blue: 0.30)
    static let subtitle = Color(red: 0.45, green: 0.45, blue: 0.58)

    // MARK: - Brand

    static let primary = Color(red: 0.40, green: 0.35, blue: 0.95)
    static let success = Color(red: 0.20, green: 0.75, blue: 0.50)
    static let warning = Color(red: 1.00, green: 0.72, blue: 0.20)
    static let star = Color(red: 1.00, green: 0.80, blue: 0.10)

    /// Playful palette used to tint letter tiles. Indexed by `Letter.colorIndex`
    /// so that the model layer stays free of SwiftUI types.
    static let palette: [Color] = [
        Color(red: 0.98, green: 0.42, blue: 0.45),  // red
        Color(red: 1.00, green: 0.62, blue: 0.28),  // orange
        Color(red: 1.00, green: 0.80, blue: 0.25),  // yellow
        Color(red: 0.35, green: 0.80, blue: 0.55),  // green
        Color(red: 0.32, green: 0.66, blue: 0.96),  // blue
        Color(red: 0.62, green: 0.48, blue: 0.94),  // purple
        Color(red: 0.96, green: 0.52, blue: 0.76)   // pink
    ]

    static func paletteColor(_ index: Int) -> Color {
        palette[((index % palette.count) + palette.count) % palette.count]
    }

    // MARK: - Neutral states

    /// Disabled control backgrounds, e.g. an unavailable primary button.
    static let disabledBackground = Color.gray.opacity(0.4)

    /// Disabled icons and "wrong answer" tile backgrounds.
    static let disabledIcon = Color.gray.opacity(0.35)

    /// Empty/unfilled slot backgrounds.
    static let emptySlot = Color.gray.opacity(0.25)
}
