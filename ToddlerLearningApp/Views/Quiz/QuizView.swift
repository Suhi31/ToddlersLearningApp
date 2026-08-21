//
//  QuizView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct QuizView: View {

    @State private var viewModel: QuizViewModel
    private let coordinator: AppCoordinator

    // Adaptive rather than a fixed 2-column grid so 4 or 5 options both lay out
    // cleanly instead of leaving an orphaned tile on its own row.
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    init(viewModel: QuizViewModel, coordinator: AppCoordinator) {
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
                    ContentUnavailableView("No letters yet",
                                           systemImage: "textformat.abc")
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.screen)

            StarBurstView(isActive: viewModel.feedback == .correct)
        }
        .navigationTitle("Find the Letter")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Wiring the callback here keeps the ViewModel free of navigation.
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
            Text(viewModel.promptEmoji)
                .font(.system(size: 220))
                .scaleEffect(viewModel.feedback == .correct ? 1.15 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.5),
                           value: viewModel.feedback)

            Text(viewModel.promptWord)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.title)

            Text("Which letter does it start with?")
                .font(AppFonts.body)
                .foregroundStyle(AppColors.subtitle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.section * 1.5)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }

    private func options(for question: QuizQuestion) -> some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(question.options) { letter in
                optionTile(letter, answer: question.answer)
            }
        }
    }

    private func optionTile(_ letter: Letter, answer: Letter) -> some View {
        let tint = AppColors.paletteColor(letter.colorIndex)

        return Button {
            viewModel.select(letter)
        } label: {
            Text(letter.uppercase)
                .font(.system(size: 84, weight: .heavy, design: .rounded))
                .foregroundStyle(foreground(for: letter, answer: answer))
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(background(for: letter, answer: answer, tint: tint))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
                .softShadow()
                .scaleEffect(scale(for: letter, answer: answer))
                .animation(.spring(response: 0.35, dampingFraction: 0.55),
                           value: viewModel.feedback)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isAcceptingInput)
        .accessibilityLabel("Letter \(letter.uppercase)")
    }

    // MARK: - Feedback styling

    private func isRevealedAnswer(_ letter: Letter, answer: Letter) -> Bool {
        // On a miss the correct tile is highlighted too, so the child's attention
        // is redirected to the right answer instead of dwelling on the error.
        if case .incorrect = viewModel.feedback { return letter.id == answer.id }
        return viewModel.feedback == .correct && letter.id == answer.id
    }

    private func isWrongPick(_ letter: Letter) -> Bool {
        if case .incorrect(let letterID) = viewModel.feedback {
            return letterID == letter.id
        }
        return false
    }

    private func background(for letter: Letter, answer: Letter, tint: Color) -> Color {
        if isRevealedAnswer(letter, answer: answer) { return AppColors.success }
        if isWrongPick(letter) { return AppColors.disabledIcon }
        return tint.opacity(0.25)
    }

    private func foreground(for letter: Letter, answer: Letter) -> Color {
        isRevealedAnswer(letter, answer: answer) ? .white : AppColors.title
    }

    private func scale(for letter: Letter, answer: Letter) -> CGFloat {
        if isRevealedAnswer(letter, answer: answer) { return 1.08 }
        if isWrongPick(letter) { return 0.94 }
        return 1.0
    }
}
