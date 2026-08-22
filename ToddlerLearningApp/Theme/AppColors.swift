//
//  AppColors.swift
//  ToddlerLearningApp
//

import SwiftUI
import UIKit

enum AppColors {

    // MARK: - Surfaces

    static let backgroundTop = Color(red: 0.99, green: 0.96, blue: 1.00)
    static let backgroundBottom = Color(red: 0.90, green: 0.96, blue: 1.00)
    static let card = Color.white

    // MARK: - Text

    static let title = Color(red: 0.16, green: 0.15, blue: 0.30)
    /// Darkened from 0.45/0.45/0.58, which measured 4.27:1 on the gradient
    /// background's light end and 4.10:1 on its dark end — both under the
    /// WCAG AA 4.5:1 floor for body text. This clears 4.5:1 across the whole
    /// gradient while staying visibly secondary to `title`.
    static let subtitle = Color(red: 0.42, green: 0.42, blue: 0.55)

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

    // MARK: - Readable ink on a filled surface

    /// Returns whichever of the app's two inks — white or the dark `title`
    /// colour — has more contrast against `background`.
    ///
    /// Neither ink works everywhere, which is why this is computed rather than
    /// fixed. The palette is deliberately light, so white on it measures
    /// between 1.50:1 (yellow) and 2.83:1 (red) — far under the WCAG AA 3:1
    /// floor for large text — while the dark ink clears 4.40:1 on every
    /// palette colour and every neutral fill. But `primary` is a deep purple
    /// where the reverse holds: white reaches 4.90:1 and the dark ink only
    /// 2.90:1. Choosing by measured luminance keeps every filled tile legible
    /// and stays correct if the palette is ever retuned.
    static func ink(on background: Color) -> Color {
        let backgroundLuminance = UIColor(background).relativeLuminance
        return contrast(1.0, backgroundLuminance)
            >= contrast(UIColor(title).relativeLuminance, backgroundLuminance)
            ? .white : title
    }

    /// WCAG 2.1 relative-luminance contrast ratio.
    private static func contrast(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let (lighter, darker) = a > b ? (a, b) : (b, a)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

private extension UIColor {

    /// WCAG 2.1 relative luminance, in sRGB.
    var relativeLuminance: CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func linear(_ channel: CGFloat) -> CGFloat {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
