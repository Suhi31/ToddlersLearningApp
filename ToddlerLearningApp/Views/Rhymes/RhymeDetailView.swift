//
//  RhymeDetailView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct RhymeDetailView: View {

    @State private var viewModel: RhymeDetailViewModel
    private let coordinator: AppCoordinator

    init(viewModel: RhymeDetailViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    private var tint: Color { AppColors.paletteColor(viewModel.rhyme.colorIndex) }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppSpacing.section) {
                Text(viewModel.rhyme.emoji)
                    .font(.system(size: 64))

                if let caption = linkageCaption {
                    Text(caption)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)
                }

                lyrics
                playButton
                practiceLink

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.screen)
        }
        .navigationTitle(viewModel.rhyme.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onSafeStoppingPoint = { coordinator.checkTimeLimitAtSafePoint() }
            viewModel.onAppear()
        }
        .onDisappear { viewModel.onDisappear() }
    }

    private var lyrics: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            ForEach(Array(viewModel.rhyme.lines.enumerated()), id: \.offset) { index, line in
                let isHighlighted = viewModel.highlightedLineIndex == index

                Text(line)
                    .font(AppFonts.body)
                    .foregroundStyle(isHighlighted ? .white : AppColors.title)
                    .padding(.horizontal, AppSpacing.tight)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isHighlighted ? tint : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .animation(.easeInOut(duration: 0.2), value: isHighlighted)
            }
        }
        .padding(AppSpacing.element)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }

    private var playButton: some View {
        Button {
            viewModel.togglePlayback()
        } label: {
            Label(
                viewModel.isPlaying ? "Pause" : "Play",
                systemImage: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill"
            )
            .font(AppFonts.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.minimumTapTarget)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
            .raisedShadow(color: tint)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private var linkageCaption: String? {
        switch viewModel.rhyme.linkage {
        case .letter(let id): "🔤 Goes with letter \(id)"
        case .number(let value): "🔢 Goes with number \(value)"
        case .general: nil
        }
    }

    @ViewBuilder
    private var practiceLink: some View {
        switch viewModel.rhyme.linkage {
        case .letter(let id):
            Button {
                coordinator.push(.learnAlphabetDetail(id))
            } label: {
                Label("Practice letter \(id)", systemImage: "arrow.right.circle.fill")
                    .font(AppFonts.caption)
                    .foregroundStyle(tint)
            }
            .buttonStyle(.plain)

        case .number(let value):
            Button {
                coordinator.push(.learnNumbersDetail(value))
            } label: {
                Label("Practice number \(value)", systemImage: "arrow.right.circle.fill")
                    .font(AppFonts.caption)
                    .foregroundStyle(tint)
            }
            .buttonStyle(.plain)

        case .general:
            EmptyView()
        }
    }
}
