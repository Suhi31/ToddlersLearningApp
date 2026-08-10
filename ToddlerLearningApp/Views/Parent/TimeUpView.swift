//
//  TimeUpView.swift
//  ToddlerLearningApp
//
//  Spec F5. The wind-down. This is deliberately a celebration rather than a
//  lock-out screen — the daily allowance should feel like finishing, not like
//  being cut off, which is the specific complaint parents raise about
//  competitors.
//

import SwiftUI

struct TimeUpView: View {

    let childName: String
    let onDismiss: () -> Void

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppSpacing.section) {
                Spacer()

                Text("🎉")
                    .font(.system(size: 96))
                    .scaleEffect(isAnimating ? 1.0 : 0.6)
                    .animation(.spring(response: 0.6, dampingFraction: 0.5), value: isAnimating)

                VStack(spacing: AppSpacing.tight) {
                    Text(childName.isEmpty ? "Great playing!" : "Great playing, \(childName)!")
                        .font(AppFonts.hero)
                        .foregroundStyle(AppColors.title)
                        .multilineTextAlignment(.center)

                    Text("That's all for today.\nSee you tomorrow! 👋")
                        .font(AppFonts.body)
                        .foregroundStyle(AppColors.subtitle)
                        .multilineTextAlignment(.center)
                }

                MascotView(emoji: "🐻", size: 90)

                Spacer()

                PrimaryButton(title: "All done") {
                    onDismiss()
                }
                .padding(.bottom, AppSpacing.section)
            }
            .padding(AppSpacing.screen)
        }
        .onAppear { isAnimating = true }
        .interactiveDismissDisabled()
    }
}

#Preview {
    TimeUpView(childName: "Ava") {}
}
