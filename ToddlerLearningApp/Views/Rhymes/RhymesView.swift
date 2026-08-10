//
//  RhymesView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct RhymesView: View {

    @State private var viewModel: RhymesViewModel
    private let coordinator: AppCoordinator

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: AppSpacing.element)]

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
        .navigationTitle("Nursery Rhymes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onAppear()
            coordinator.checkTimeLimitAtSafePoint()
        }
    }

    private func card(for rhyme: Rhyme) -> some View {
        let tint = AppColors.paletteColor(rhyme.colorIndex)

        return Button {
            viewModel.selected(rhyme)
            coordinator.push(.rhymeDetail(rhyme.id))
        } label: {
            VStack(spacing: AppSpacing.tight) {
                Text(rhyme.emoji)
                    .font(.system(size: 44))
                    .frame(width: 68, height: 68)
                    .background(tint.opacity(0.22))
                    .clipShape(Circle())

                Text(rhyme.title)
                    .font(AppFonts.body)
                    .foregroundStyle(AppColors.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let caption = viewModel.linkageCaption(for: rhyme) {
                    Text(caption)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.element)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
            .softShadow()
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel(rhyme.title)
    }
}
