//
//  WordBuildView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct WordBuildView: View {

    @State private var viewModel: WordBuildViewModel
    private let coordinator: AppCoordinator

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Slot and tile sizes grow on a wide screen — at 56/60pt they were
    /// thumbnail-sized on an iPad.
    private var tileSide: CGFloat { horizontalSizeClass == .regular ? 96 : 60 }
    private var slotWidth: CGFloat { horizontalSizeClass == .regular ? 88 : 56 }
    private var slotHeight: CGFloat { horizontalSizeClass == .regular ? 100 : 64 }

    private var letterColumns: [GridItem] {
        [GridItem(.adaptive(minimum: tileSide), spacing: 12)]
    }

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

            // Only for a word that earned its star — see `missesAllowedForStar`.
            StarBurstView(isActive: viewModel.didEarnStar)

            // Spec F27: a finish line rather than the activity running
            // forever. Covers the content above rather than replacing it,
            // same convention as `StarBurstView`.
            if viewModel.isRoundComplete {
                RoundCompleteView(
                    starsEarned: viewModel.starsThisRound,
                    onPlayAgain: { viewModel.startNewRound() },
                    onDone: { coordinator.popToRoot() }
                )
            }
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
        VStack(spacing: AppSpacing.tight) {
            HStack {
                Label("\(viewModel.starsThisSession)", systemImage: "star.fill")
                    .font(AppFonts.body)
                    .foregroundStyle(AppColors.star)
                Spacer()
            }

            HStack(spacing: AppSpacing.tight) {
                ProgressBar(
                    value: Double(viewModel.wordsCompleted) / Double(viewModel.wordsPerRound),
                    tint: AppColors.primary,
                    height: 8
                )
                Text("\(viewModel.wordsCompleted) of \(viewModel.wordsPerRound)")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.subtitle)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    /// Tapping the picture hears the word and the question again — the small
    /// speaker badge is there so it reads as something to tap.
    private var picture: some View {
        Button {
            viewModel.repeatPrompt()
        } label: {
            Text(viewModel.promptEmoji)
                .font(.system(size: 90))
                .overlay(alignment: .bottomTrailing) {
                    SpeakerBadge()
                        .offset(x: 8, y: 4)
                }
        }
        .buttonStyle(BouncyButtonStyle())
        .scaleEffect(viewModel.isComplete ? 1.15 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: viewModel.isComplete)
        .accessibilityLabel("Hear the word again")
    }

    private var slots: some View {
        HStack(spacing: 10) {
            ForEach(Array(viewModel.filledLetters.enumerated()), id: \.offset) { index, letter in
                let fill = letter == nil ? AppColors.emptySlot : AppColors.success
                Text(letter ?? "")
                    .font(.system(size: slotHeight * 0.62, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.ink(on: fill))
                    .frame(width: slotWidth, height: slotHeight)
                    .background(fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    // The slot being asked about, so the child knows which
                    // letter the question means.
                    .overlay {
                        if index == viewModel.nextSlotIndex, !viewModel.isComplete {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.primary, lineWidth: 3)
                        }
                    }
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
                        .font(.system(size: tileSide * 0.53, weight: .heavy, design: .rounded))
                        .foregroundStyle(tile.isRejected ? AppColors.subtitle : AppColors.title)
                        .frame(width: tileSide, height: tileSide)
                        .background(tileBackground(tile))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        // The tile shown after repeated misses on one letter.
                        .overlay {
                            if tile.id == viewModel.revealedTileID {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.success, lineWidth: 4)
                            }
                        }
                        .shadow(color: tile.id == viewModel.revealedTileID ? AppColors.success.opacity(0.6) : .clear,
                                radius: 10)
                }
                .buttonStyle(.plain)
                .disabled(tile.isUsed || tile.isRejected || viewModel.isComplete || viewModel.isLocked)
                .opacity(tile.isUsed ? 0.3 : (tile.isRejected ? 0.5 : 1.0))
                .keyframeAnimator(initialValue: CGFloat(0), trigger: tile.shakes) { content, offset in
                    content.offset(x: offset)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        LinearKeyframe(-10, duration: 0.06)
                        LinearKeyframe(10, duration: 0.08)
                        LinearKeyframe(-6, duration: 0.08)
                        LinearKeyframe(6, duration: 0.08)
                        LinearKeyframe(0, duration: 0.06)
                    }
                }
                .accessibilityLabel("Letter \(tile.letter)")
                .accessibilityValue(tile.isRejected ? "Not this one" : "")
            }
        }
    }

    private func tileBackground(_ tile: WordBuildViewModel.ScrambledLetter) -> Color {
        if tile.id == viewModel.revealedTileID { return AppColors.success.opacity(0.35) }
        if tile.isRejected { return AppColors.disabledIcon.opacity(0.35) }
        return AppColors.primary.opacity(tile.isUsed ? 0.08 : 0.25)
    }
}
