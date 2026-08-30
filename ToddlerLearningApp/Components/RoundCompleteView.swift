//
//  RoundCompleteView.swift
//  ToddlerLearningApp
//
//  Spec F27. The finish line every bounded round (quiz, Build the Word, Trace)
//  shares: a celebration overlay in place of "just keep going forever until
//  the child backs out." Deliberately reuses the app's existing celebration
//  vocabulary — `StarBurstView`, `MascotView`, `PrimaryButton` — rather than
//  inventing a second one; the closest sibling is `TimeUpView`, which is a
//  full navigation destination rather than an in-place overlay, so this
//  isn't a shared type with it, just a shared look.
//

import SwiftUI

struct RoundCompleteView: View {

    let starsEarned: Int
    let onPlayAgain: () -> Void
    let onDone: () -> Void

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppSpacing.section) {
                Spacer()

                MascotView(emoji: "🎉", size: 90)

                VStack(spacing: AppSpacing.tight) {
                    Text("Round complete!")
                        .font(AppFonts.hero)
                        .foregroundStyle(AppColors.title)
                        .multilineTextAlignment(.center)

                    Label("\(starsEarned) stars", systemImage: "star.fill")
                        .font(AppFonts.heading)
                        .foregroundStyle(AppColors.star)
                }

                Spacer()

                VStack(spacing: AppSpacing.element) {
                    PrimaryButton(title: "🔄 Play Again") {
                        onPlayAgain()
                    }

                    Button("Done") {
                        onDone()
                    }
                    .font(AppFonts.body)
                    .foregroundStyle(AppColors.subtitle)
                }
                .padding(.bottom, AppSpacing.section)
            }
            .padding(AppSpacing.screen)

            StarBurstView(isActive: isAnimating)
        }
        .onAppear { isAnimating = true }
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    RoundCompleteView(starsEarned: 10, onPlayAgain: {}, onDone: {})
}
