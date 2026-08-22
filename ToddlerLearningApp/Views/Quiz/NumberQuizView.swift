//
//  NumberQuizView.swift
//  ToddlerLearningApp
//
//  Numbers-domain twin of QuizView. The prompt is a grid of repeated emoji to
//  count rather than a single picture, since the question is "how many?" not
//  "which letter?" — and that difference is now the only thing this file
//  carries; the rest is QuizScreen.
//

import SwiftUI

struct NumberQuizView: View {

    @State private var viewModel: NumberQuizViewModel
    private let coordinator: AppCoordinator

    // Adaptive, not a fixed 5-across grid, so items get room to breathe instead
    // of packing edge-to-edge — cramped items are hard for a toddler to
    // visually separate while counting. See QuizLayoutMetrics for the minimum.
    private let promptColumns = [
        GridItem(.adaptive(minimum: QuizLayoutMetrics.countingMinimumWidth,
                           maximum: 96),
                 spacing: 10)
    ]

    init(viewModel: NumberQuizViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        QuizScreen(
            viewModel: viewModel,
            coordinator: coordinator,
            title: "Count & Find",
            emptyTitle: "No numbers yet",
            emptySymbol: "number",
            tint: { AppColors.paletteColor(NumberContent.number(id: $0)?.colorIndex ?? 0) },
            label: { "\($0)" },
            optionAccessibilityLabel: { "Number \($0)" }
        ) { metrics in
            prompt(metrics)
        }
    }

    private func prompt(_ metrics: QuizLayoutMetrics) -> some View {
        VStack(spacing: AppSpacing.tight) {
            LazyVGrid(columns: promptColumns, spacing: 10) {
                ForEach(0..<viewModel.promptCount, id: \.self) { _ in
                    Text(viewModel.promptEmoji)
                        .font(.system(size: metrics.countingEmojiSize))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.element)
            .scaleEffect(viewModel.feedback == .correct ? 1.1 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5),
                       value: viewModel.feedback)

            Text("How many do you see?")
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
