//
//  AppSpacing.swift
//  ToddlerLearningApp
//

import CoreGraphics

enum AppSpacing {

    static let tight: CGFloat = 8
    static let element: CGFloat = 16
    static let section: CGFloat = 24
    static let screen: CGFloat = 20

    static let cornerRadius: CGFloat = 20
    static let tileCornerRadius: CGFloat = 16

    /// Minimum tap target. Deliberately larger than Apple's 44pt guidance —
    /// toddlers have poor fine-motor accuracy.
    static let minimumTapTarget: CGFloat = 64
}
