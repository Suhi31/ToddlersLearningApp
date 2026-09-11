//
//  StarBurstView.swift
//  ToddlerLearningApp
//

import SwiftUI

/// The celebration on a correct answer. Purely decorative and non-interactive,
/// so it stays hidden from assistive technology.
///
/// Played as keyframes each time `isActive` changes, rather than by animating
/// between two fixed states. The two-state version had to leave the stars
/// fully visible at rest — the burst *was* them fading out as they flew — so a
/// little heap of shrunken stars sat in the middle of every screen that uses
/// this, and flew back into it after each celebration.
struct StarBurstView: View {

    let isActive: Bool

    private let starCount = 8

    /// How long each star takes to fly out and fade.
    private let flightDuration: Double = 0.7

    /// One star's position along its burst. Starts — and ends — invisible.
    private struct Burst {
        var distance: CGFloat = 0
        var scale: CGFloat = 0.3
        var opacity: Double = 0
    }

    var body: some View {
        ZStack {
            ForEach(0..<starCount, id: \.self) { index in
                let angle = Double(index) / Double(starCount) * 2 * .pi
                let delay = Double(index) * 0.02

                Text("⭐️")
                    .font(.system(size: 26))
                    .keyframeAnimator(initialValue: Burst(), trigger: isActive) { star, burst in
                        star
                            .scaleEffect(burst.scale)
                            .offset(x: cos(angle) * burst.distance, y: sin(angle) * burst.distance)
                            // The keyframes replay whenever `isActive` changes,
                            // including back to false when the celebration
                            // ends — that replay has nothing to show.
                            .opacity(isActive ? burst.opacity : 0)
                    } keyframes: { _ in
                        KeyframeTrack(\.distance) {
                            LinearKeyframe(0, duration: delay)
                            CubicKeyframe(90, duration: flightDuration)
                        }
                        KeyframeTrack(\.scale) {
                            LinearKeyframe(0.3, duration: delay)
                            CubicKeyframe(1.4, duration: flightDuration)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(1, duration: delay + 0.05)
                            CubicKeyframe(0, duration: flightDuration)
                        }
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    StarBurstView(isActive: true)
}
