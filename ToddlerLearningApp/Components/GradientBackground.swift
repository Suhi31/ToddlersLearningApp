//
//  GradientBackground.swift
//  ToddlerLearningApp
//

import SwiftUI

struct GradientBackground: View {

    var body: some View {
        LinearGradient(
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    GradientBackground()
}
