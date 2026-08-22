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

    private func prompt(_ metrics: QuizLayoutMetrics) -> some View {
        VStack(spacing: AppSpacing.tight) {
            Text(viewModel.promptEmoji)
                .font(.system(size: metrics.promptEmojiSize))
                .scaleEffect(viewModel.feedback == .correct ? 1.15 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.5),
                           value: viewModel.feedback)

            Text(viewModel.promptWord)
                .font(AppFonts.hero.weight(.bold))
                .foregroundStyle(AppColors.title)

            Text("Which letter does it start with?")
                .font(AppFonts.body)
                .foregroundStyle(AppColors.subtitle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.section)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }
}
