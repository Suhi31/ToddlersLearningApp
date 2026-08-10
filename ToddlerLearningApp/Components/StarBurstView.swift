//
//  StarBurstView.swift
//  ToddlerLearningApp
//

import SwiftUI

/// The celebration on a correct answer. Purely decorative and non-interactive,
/// so it stays hidden from assistive technology.
struct StarBurstView: View {

    let isActive: Bool

    private let starCount = 8

    var body: some View {
        ZStack {
            ForEach(0..<starCount, id: \.self) { index in
                let angle = Double(index) / Double(starCount) * 2 * .pi

                Text("⭐️")
                    .font(.system(size: 26))
                    .offset(
                        x: isActive ? cos(angle) * 90 : 0,
                        y: isActive ? sin(angle) * 90 : 0
                    )
                    .opacity(isActive ? 0 : 1)
                    .scaleEffect(isActive ? 1.4 : 0.3)
                    .animation(
                        .easeOut(duration: 0.7).delay(Double(index) * 0.02),
                        value: isActive
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    StarBurstView(isActive: true)
}
