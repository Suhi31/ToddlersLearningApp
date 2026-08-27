//
//  QuizScreen.swift
//  ToddlerLearningApp
//
//  The shared chrome behind the letter quiz and the number quiz: score bar,
//  option grid, feedback styling, star burst, sizing, and the
//  safe-stopping-point wiring. `QuizEngineViewModel<Domain>` already
//  generified the behaviour, but the two views had stayed verbatim copies —
//  `isRevealedAnswer`, `isWrongPick`, `background(for:)`, `foreground(for:)`
//  and `scale(for:)` existed twice, differing only in `Letter` vs `Int`.
//
//  Only the prompt card and the label inside an option tile genuinely differ,
//  so those are what the caller supplies.
//

import SwiftUI

struct QuizScreen<Domain: QuizDomain, Prompt: View>: View {

    /// A plain `let`, not `@State`: the owning screen creates and owns the
    /// view model, and `@Observable` means reading it here still tracks.
    let viewModel: QuizEngineViewModel<Domain>

    let coordinator: AppCoordinator
    let title: String

    /// Shown when the adaptive selector has nothing to ask.
    let emptyTitle: String
    let emptySymbol: String

    /// Tint for one option, and the glyph on it.
    let tint: (Domain.Selection) -> Color
    let label: (Domain.Selection) -> String

    /// VoiceOver label for one option, e.g. "Letter B".
    let optionAccessibilityLabel: (Domain.Selection) -> String

    @ViewBuilder let prompt: (QuizLayoutMetrics) -> Prompt

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// A phone in landscape has ~330pt of height — nowhere near enough to stack
    /// a prompt card above two rows of answer tiles. Side by side instead.
    private var isShort: Bool { verticalSizeClass == .compact }

    /// Explicit `.flexible()` columns rather than `.adaptive`, capped at the
    /// number of options — see `QuizLayoutMetrics.columnCount(for:...)` for why
    /// adaptive left the row hanging to the left on a wide screen.
    private func optionColumns(_ metrics: QuizLayoutMetrics) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: QuizLayoutMetrics.optionSpacing),
            count: metrics.columnCount(for: viewModel.options.count,
                                       minimumWidth: QuizLayoutMetrics.optionMinimumWidth,
                                       spacing: QuizLayoutMetrics.optionSpacing)
        )
    }

    var body: some View {
        ZStack {
            GradientBackground()

            GeometryReader { geometry in
                let metrics = QuizLayoutMetrics(size: geometry.size,
                                                isRegular: horizontalSizeClass == .regular,
                                                isShort: isShort)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.section) {
                        scoreBar

                        if viewModel.question != nil {
                            if isShort {
                                HStack(alignment: .center, spacing: AppSpacing.section) {
                                    prompt(metrics)
                                        .frame(maxWidth: .infinity)
                                    optionGrid(metrics)
                                        .frame(maxWidth: .infinity)
                                }
                            } else {
                                prompt(metrics)
                                optionGrid(metrics)
                            }
                        } else {
                            ContentUnavailableView(emptyTitle, systemImage: emptySymbol)
                        }
                    }
                    .padding(AppSpacing.screen)
                    // Fills the screen when the content is shorter, which is the
                    // normal case now that everything is sized to fit, and
                    // replaces a trailing Spacer.
                    //
                    // Top-aligned on a phone, where the content very nearly
                    // fills the screen anyway. Centred on a wide screen: a
                    // five-tile quiz can't sensibly fill an iPad's height, and
                    // balanced margins read as deliberate where a single large
                    // gap under the tiles reads as a layout bug.
                    .frame(minHeight: geometry.size.height,
                           alignment: metrics.isRegular ? .center : .top)
                }
            }

            StarBurstView(isActive: viewModel.feedback == .correct)
        }
        .childScreenTypeSize()
        .navigationTitle(title)
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

    private func optionGrid(_ metrics: QuizLayoutMetrics) -> some View {
        LazyVGrid(columns: optionColumns(metrics), spacing: QuizLayoutMetrics.optionSpacing) {
            ForEach(viewModel.options, id: \.self) { option in
                optionTile(option, metrics: metrics)
            }
        }
    }

    private func optionTile(_ option: Domain.Selection,
                            metrics: QuizLayoutMetrics) -> some View {
        Button {
            viewModel.select(option)
        } label: {
            Text(label(option))
                .font(.system(size: metrics.optionLabelSize, weight: .heavy, design: .rounded))
                .foregroundStyle(foreground(option))
                .frame(maxWidth: .infinity)
                .frame(height: metrics.optionTileHeight)
                .background(background(option))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
                .softShadow()
                .scaleEffect(scale(option))
                .animation(.spring(response: 0.35, dampingFraction: 0.55),
                           value: viewModel.feedback)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isAcceptingInput)
        .accessibilityLabel(optionAccessibilityLabel(option))
        .accessibilityValue(accessibilityValue(option))
    }

    // MARK: - Feedback styling

    /// On a miss the correct tile is highlighted too, so the child's attention
    /// is redirected to the right answer instead of dwelling on the error.
    private func isRevealedAnswer(_ option: Domain.Selection) -> Bool {
        guard viewModel.answer(for: option) == viewModel.currentAnswer else { return false }
        if case .incorrect = viewModel.feedback { return true }
        return viewModel.feedback == .correct
    }

    private func isWrongPick(_ option: Domain.Selection) -> Bool {
        if case .incorrect(let picked) = viewModel.feedback {
            return picked == viewModel.answer(for: option)
        }
        return false
    }

    private func background(_ option: Domain.Selection) -> Color {
        if isRevealedAnswer(option) { return AppColors.success }
        if isWrongPick(option) { return AppColors.disabledIcon }
        return tint(option).opacity(0.25)
    }

    private func foreground(_ option: Domain.Selection) -> Color {
        isRevealedAnswer(option) ? AppColors.ink(on: AppColors.success) : AppColors.title
    }

    private func scale(_ option: Domain.Selection) -> CGFloat {
        if isRevealedAnswer(option) { return 1.08 }
        if isWrongPick(option) { return 0.94 }
        return 1.0
    }

    /// The correct/incorrect styling is colour and scale only, which conveys
    /// nothing to VoiceOver. Deliberately no `AccessibilityNotification`
    /// announcement alongside it: the app already speaks praise or the correct
    /// answer aloud through `SpeechService` on every answer, and an
    /// announcement would talk straight over its own audio.
    private func accessibilityValue(_ option: Domain.Selection) -> String {
        if isWrongPick(option) { return "Not this one" }
        if isRevealedAnswer(option) { return "Correct answer" }
        return ""
    }
}
