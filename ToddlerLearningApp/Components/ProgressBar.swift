//
//  ProgressBar.swift
//  ToddlerLearningApp
//

import SwiftUI

struct ProgressBar: View {

    /// 0...1, clamped.
    let value: Double
    var tint: Color = AppColors.success
    var height: CGFloat = 14

    private var clamped: Double { min(max(value, 0), 1) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))

                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * clamped)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: clamped)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(clamped * 100)) percent")
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressBar(value: 0.3)
        ProgressBar(value: 0.85)
    }
    .padding()
}
