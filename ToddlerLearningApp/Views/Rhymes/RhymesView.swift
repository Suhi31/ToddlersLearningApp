//
//  RhymesView.swift
//  ToddlerLearningApp
//
//  Artwork-led tiles: the picture is how a child who can't read the title picks
//  a song, so it takes most of the tile and the words caption it.
//

import SwiftUI

struct RhymesView: View {

    @State private var viewModel: RhymesViewModel
    private let coordinator: AppCoordinator

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        let layout = AdaptiveLayout(size: .zero, horizontalSizeClass: horizontalSizeClass)
        return [GridItem(.adaptive(minimum: layout.rhymeTileMinimumWidth),
                         spacing: AppSpacing.element)]
    }

    init(viewModel: RhymesViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: AppSpacing.element) {
                    ForEach(viewModel.rhymes) { rhyme in
                        card(for: rhyme)
                    }
                }
                .padding(AppSpacing.screen)
            }
        }
        .childScreenTypeSize()
        .navigationTitle("Nursery Rhymes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onAppear()
            coordinator.checkTimeLimitAtSafePoint()
        }
    }

    private func card(for rhyme: Rhyme) -> some View {
        let tint = AppColors.paletteColor(rhyme.colorIndex)
        let isCurrent = viewModel.isCurrent(rhyme)
        let isPlaying = viewModel.isPlaying(rhyme)

        return Button {
            viewModel.selected(rhyme)
            coordinator.push(.rhymeDetail(rhyme.id))
        } label: {
            VStack(spacing: AppSpacing.tight) {
                ZStack(alignment: .topTrailing) {
                    Text(rhyme.emoji)
                        .font(.system(size: 62))
                        .frame(maxWidth: .infinity)
                        .frame(height: 112)
                        // The rhyme being listened to fills with its colour
                        // rather than a wash of it — the same "this is the one"
                        // vocabulary the letter and number tiles use.
                        .background(tint.opacity(isCurrent ? 0.85 : 0.22),
                                    in: RoundedRectangle(cornerRadius: AppSpacing.tileCornerRadius))

                    if isCurrent {
                        // Static, not an animated equaliser: toddlers already
                        // know the speaker, and it survives Reduce Motion.
                        Image(systemName: isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.ink(on: tint))
                            .padding(AppSpacing.tight)
                    }
                }
                .glow(tint, active: isPlaying)

                // Every tile is the same size whatever it holds: titles run
                // from one line ("Pat-a-Cake") to three ("She'll Be Coming
                // 'Round the Mountain"), and only half the rhymes have a tie-in
                // caption, so both blocks reserve their space rather than
                // sizing to their content. Reserved in *lines* rather than
                // points, so it still holds when the text scales up.
                Text(rhyme.title)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.8)

                // A space, not nothing, for the 11 rhymes that tie to neither a
                // letter nor a number.
                Text(viewModel.linkageCaption(for: rhyme) ?? " ")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.subtitle)
                    .multilineTextAlignment(.center)
                    .lineLimit(1, reservesSpace: true)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.tight)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
            .softShadow()
        }
        .buttonStyle(BouncyButtonStyle())
        // Combined so the tie-in caption is read too — it was dropped when the
        // label was just the title.
        .accessibilityElement(children: .combine)
        .accessibilityValue(isCurrent ? (isPlaying ? "Playing" : "Paused") : "")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
