//
//  WordBuildView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct WordBuildView: View {

    @State private var viewModel: WordBuildViewModel
    private let coordinator: AppCoordinator

    private let letterColumns = [GridItem(.adaptive(minimum: 60), spacing: 12)]

    init(viewModel: WordBuildViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppSpacing.section) {
                scoreBar
                picture
                slots
                scrambledTiles

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.screen)

            StarBurstView(isActive: viewModel.isComplete)
        }
        .childScreenTypeSize()
        .navigationTitle("Build the Word")
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
        }
    }

    private var picture: some View {
        Text(viewModel.promptEmoji)
            .font(.system(size: 90))
            .scaleEffect(viewModel.isComplete ? 1.15 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: viewModel.isComplete)
    }

    private var slots: some View {
        HStack(spacing: 10) {
            ForEach(Array(viewModel.filledLetters.enumerated()), id: \.offset) { index, letter in
                let fill = letter == nil ? AppColors.emptySlot : AppColors.success
                Text(letter ?? "")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.ink(on: fill))
                    .frame(width: 56, height: 64)
                    .background(fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    // An unfilled slot renders as an empty string, so without
                    // this VoiceOver reads the row as nothing at all and the
                    // puzzle's state is undiscoverable.
                    .accessibilityLabel("Letter \(index + 1)")
                    .accessibilityValue(letter ?? "empty")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spelling \(viewModel.currentWord.id.capitalized)")
    }

    private var scrambledTiles: some View {
        LazyVGrid(columns: letterColumns, spacing: 12) {
            ForEach(viewModel.scrambledLetters) { tile in
                Button {
                    viewModel.tapScrambled(tile)
                } label: {
                    Text(tile.letter)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.title)
                        .frame(width: 60, height: 60)
                        .background(AppColors.primary.opacity(tile.isUsed ? 0.08 : 0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(tile.isUsed || viewModel.isComplete)
                .opacity(tile.isUsed ? 0.3 : 1.0)
                .accessibilityLabel("Letter \(tile.letter)")
            }
        }
    }
}
