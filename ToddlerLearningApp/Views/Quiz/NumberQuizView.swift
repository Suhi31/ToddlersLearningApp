//
//  NumberQuizView.swift
//  ToddlerLearningApp
//
//  Numbers-domain twin of QuizView. The prompt is a grid of repeated emoji to
//  count rather than a single picture, since the question is "how many?" not
//  "which letter?".
//

import SwiftUI

struct NumberQuizView: View {

    @State private var viewModel: NumberQuizViewModel
    private let coordinator: AppCoordinator

    private let optionColumns = [GridItem(.adaptive(minimum: 100), spacing: 14)]
    private let promptColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    init(viewModel: NumberQuizViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppSpacing.section) {
                scoreBar

                if let question = viewModel.question {
                    prompt
                    options(for: question)
                } else {
                    ContentUnavailableView("No numbers yet",
                                           systemImage: "number")
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.screen)

            StarBurstView(isActive: viewModel.feedback == .correct)
        }
        .navigationTitle("Count & Find")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onSafeStoppingPoint = { coordinator.checkTimeLimitAtSafePoint() }
            viewModel.onAppear()
        }
        .onDisappear { viewModel.onDisappear() }
    }

    private var scoreBar: some View {
        HStack {
            Label("\(viewModel.starsThisSession)", systemImage: "star.fill")
                .font(AppFonts.body)
                .foregroundStyle(AppColors.star)

            Spacer()

            Button {
                viewModel.repeatPrompt()
            } label: {
                Label("Say again", systemImage: "arrow.clockwise")
                    .font(AppFonts.caption)
            }
            .accessibilityLabel("Repeat the question")
        }
    }

    private var prompt: some View {
        VStack(spacing: AppSpacing.tight) {
            LazyVGrid(columns: promptColumns, spacing: 6) {
                ForEach(0..<viewModel.promptCount, id: \.self) { _ in
                    Text(viewModel.promptEmoji)
                        .font(.system(size: 40))
                }
            }
            .frame(maxWidth: 260)
            .scaleEffect(viewModel.feedback == .correct ? 1.1 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5),
                       value: viewModel.feedback)

            Text("How many do you see?")
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.subtitle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.section)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }

    private func options(for question: NumberQuizQuestion) -> some View {
        LazyVGrid(columns: optionColumns, spacing: 14) {
            ForEach(question.options, id: \.self) { value in
                optionTile(value, answer: question.answer.id)
            }
        }
    }

    private func optionTile(_ value: Int, answer: Int) -> some View {
        let tint = AppColors.paletteColor(NumberContent.number(id: value)?.colorIndex ?? 0)

        return Button {
            viewModel.select(value)
        } label: {
            Text("\(value)")
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(foreground(for: value, answer: answer))
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(background(for: value, answer: answer, tint: tint))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
                .softShadow()
                .scaleEffect(scale(for: value, answer: answer))
                .animation(.spring(response: 0.35, dampingFraction: 0.55),
                           value: viewModel.feedback)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isAcceptingInput)
        .accessibilityLabel("Number \(value)")
    }

    // MARK: - Feedback styling

    private func isRevealedAnswer(_ value: Int, answer: Int) -> Bool {
        if case .incorrect = viewModel.feedback { return value == answer }
        return viewModel.feedback == .correct && value == answer
    }

    private func isWrongPick(_ value: Int) -> Bool {
        if case .incorrect(let picked) = viewModel.feedback {
            return picked == value
        }
        return false
    }

    private func background(for value: Int, answer: Int, tint: Color) -> Color {
        if isRevealedAnswer(value, answer: answer) { return AppColors.success }
        if isWrongPick(value) { return AppColors.disabledIcon }
        return tint.opacity(0.25)
    }

    private func foreground(for value: Int, answer: Int) -> Color {
        isRevealedAnswer(value, answer: answer) ? .white : AppColors.title
    }

    private func scale(for value: Int, answer: Int) -> CGFloat {
        if isRevealedAnswer(value, answer: answer) { return 1.08 }
        if isWrongPick(value) { return 0.94 }
        return 1.0
    }
}
