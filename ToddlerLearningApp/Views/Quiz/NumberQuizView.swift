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

    private static let countingSpacing: CGFloat = 10

    /// Sized so items get room to breathe instead of packing edge-to-edge —
    /// cramped items are hard for a toddler to visually separate while
    /// counting — and capped at the number of items so the row centres rather
    /// than hanging left against a gap on a wide screen.
    private func promptColumns(_ metrics: QuizLayoutMetrics) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Self.countingSpacing),
            count: metrics.columnCount(for: viewModel.promptCount,
                                       minimumWidth: QuizLayoutMetrics.countingMinimumWidth,
                                       spacing: Self.countingSpacing,
                                       // the counting grid sits inside the
                                       // card's own horizontal padding
                                       horizontalInset: AppSpacing.element * 2)
        )
    }

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
            LazyVGrid(columns: promptColumns(metrics), spacing: Self.countingSpacing) {
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

            Text(viewModel.promptText)
                .font(AppFonts.body)
                .foregroundStyle(AppColors.subtitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.element)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.section)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
        // Deliberately *not* tap-to-replay, unlike the single picture in the
        // other games: here the child touches each object as they count it, so
        // replaying on tap fires constantly and talks over the counting. The
        // "Say again" button in the score bar is this screen's repeat.
    }
}
