//
//  Shadows.swift
//  ToddlerLearningApp
//

import SwiftUI

extension View {

    /// Soft lift used by cards and tiles.
    func softShadow() -> some View {
        shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
    }

    /// Stronger lift for primary actions.
    func raisedShadow(color: Color = AppColors.primary) -> some View {
        shadow(color: color.opacity(0.35), radius: 14, x: 0, y: 8)
    }

    /// Glow used to confirm a correct tap.
    func glow(_ color: Color, active: Bool) -> some View {
        shadow(color: active ? color.opacity(0.85) : .clear,
               radius: active ? 18 : 0)
    }
}
