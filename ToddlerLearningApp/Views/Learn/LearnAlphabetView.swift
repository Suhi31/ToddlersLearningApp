//
//  LearnAlphabetView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct LearnAlphabetView: View {

    @State private var viewModel: LearnAlphabetViewModel
    private let coordinator: AppCoordinator

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    init(viewModel: LearnAlphabetViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppSpacing.element) {
                if let letter = viewModel.currentLetter {
                    letterStage(letter)
                }

                navigationControls
                letterStrip
            }
            .padding(AppSpacing.screen)
        }
        .navigationTitle("Learn Letters")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onSafeStoppingPoint = { coordinator.checkTimeLimitAtSafePoint() }
            viewModel.onAppear()
        }
        .onDisappear { viewModel.onDisappear() }
    }

    private func letterStage(_ letter: Letter) -> some View {
        let tint = AppColors.paletteColor(letter.colorIndex)

        return VStack(spacing: AppSpacing.tight) {
            Text(letter.uppercase)
                .font(AppFonts.letterHero)
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: letter)

            Text(letter.word)
                .font(AppFonts.heading)
                .foregroundStyle(AppColors.title)

            HStack(spacing: AppSpacing.section) {
                ForEach(letter.emojis, id: \.self) { emoji in
                    Text(emoji).font(.system(size: 54))
                }
            }

            Button {
                viewModel.repeatSound()
            } label: {
                Label("Hear it again", systemImage: "speaker.wave.2.fill")
                    .font(AppFonts.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.section)
                    .frame(height: 52)
                    .background(tint)
                    .clipShape(Capsule())
            }
            .buttonStyle(BouncyButtonStyle())
            .padding(.top, AppSpacing.tight)

            if let rhyme = RhymeContent.rhymes(forLetter: letter.id).first {
                Button {
                    coordinator.push(.rhymeDetail(rhyme.id))
                } label: {
                    Label("Hear a rhyme", systemImage: "music.note")
                        .font(AppFonts.caption)
                        .foregroundStyle(tint)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.element)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }

    private var navigationControls: some View {
        HStack {
            arrowButton("chevron.left.circle.fill",
                        enabled: viewModel.canGoBack,
                        label: "Previous letter") {
                viewModel.previous()
            }

            Spacer()

            Text(viewModel.positionCaption)
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.subtitle)

            Spacer()

            arrowButton("chevron.right.circle.fill",
                        enabled: viewModel.canGoForward,
                        label: "Next letter") {
                viewModel.next()
            }
        }
        .padding(.horizontal, AppSpacing.section)
    }

    private func arrowButton(_ systemName: String,
                             enabled: Bool,
                             label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 46))
                .foregroundStyle(enabled ? AppColors.primary : AppColors.disabledIcon)
                .frame(width: AppSpacing.minimumTapTarget, height: AppSpacing.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// Jumping straight to a letter matters — a child who wants "M" for their
    /// own name should not have to page through twelve others.
    private var letterStrip: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(viewModel.letters) { letter in
                    LetterTile(
                        letter: letter,
                        mastery: viewModel.mastery(for: letter),
                        isHighlighted: letter == viewModel.currentLetter
                    ) {
                        viewModel.jump(to: letter)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxHeight: 200)
    }
}
