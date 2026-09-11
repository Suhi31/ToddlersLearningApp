//
//  QuizView.swift
//  ToddlerLearningApp
//
//  Everything except the prompt card lives in QuizScreen, shared with the
//  number quiz.
//

import SwiftUI

struct QuizView: View {

    @State private var viewModel: QuizViewModel
    private let coordinator: AppCoordinator

    init(viewModel: QuizViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        QuizScreen(
            viewModel: viewModel,
            coordinator: coordinator,
            title: "Find the Letter",
            emptyTitle: "No letters yet",
            emptySymbol: "textformat.abc",
            tint: { AppColors.paletteColor($0.colorIndex) },
            label: \.uppercase,
            optionAccessibilityLabel: { "Letter \($0.uppercase)" }
        ) { metrics in
            prompt(metrics)
        }
    }

    /// The picture is on show throughout as a clue. Its *word* stays unwritten
    /// until the letter is found — "Apple" in big type would spell the answer
    /// out as its own first letter.
    private func prompt(_ metrics: QuizLayoutMetrics) -> some View {
        let isFound = viewModel.feedback == .correct

        return VStack(spacing: AppSpacing.tight) {
            Text(viewModel.picture?.emoji ?? "")
                .font(.system(size: metrics.promptEmojiSize))
                .scaleEffect(isFound ? 1.15 : 1.0)

            // Both lines are always laid out, one of them hidden, so the card
            // keeps its height when it flips instead of the tiles below jumping.
            ZStack {
                listenRow
                    .opacity(isFound ? 0 : 1)
                    .allowsHitTesting(!isFound)
                    .accessibilityHidden(isFound)

                Text(viewModel.foundCaption)
                    .font(AppFonts.hero.weight(.bold))
                    .foregroundStyle(AppColors.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .opacity(isFound ? 1 : 0)
                    .scaleEffect(isFound ? 1.0 : 0.8)
                    .accessibilityHidden(!isFound)
            }
            .padding(.horizontal, AppSpacing.element)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isFound)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.section)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }

    private var listenRow: some View {
        HStack(spacing: AppSpacing.tight) {
            Button {
                viewModel.repeatPrompt()
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(AppFonts.heading.weight(.bold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 48, height: 48)
                    .background(AppColors.primary.opacity(0.15), in: Circle())
            }
            .buttonStyle(BouncyButtonStyle())
            .accessibilityLabel("Hear the letter again")

            Text("Find the letter you hear")
                .font(AppFonts.body)
                .foregroundStyle(AppColors.subtitle)
                .lineLimit(2)
        }
    }
}
