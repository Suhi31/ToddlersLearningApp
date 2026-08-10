//
//  RewardsView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct RewardsView: View {

    @State private var viewModel: RewardsViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    init(viewModel: RewardsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.section) {
                    summaryCard

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.trophies) { trophy in
                            trophyTile(trophy)
                        }
                    }
                }
                .padding(AppSpacing.screen)
            }
        }
        .navigationTitle("My Rewards")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(spacing: AppSpacing.tight) {
            Text("⭐️ \(viewModel.starCount)")
                .font(AppFonts.hero)
                .foregroundStyle(AppColors.title)

            Text(viewModel.summary)
                .font(AppFonts.body)
                .foregroundStyle(AppColors.subtitle)

            Text(viewModel.streakCaption)
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.subtitle)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.section)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }

    /// Locked trophies stay visible but desaturated — showing what is still
    /// available is the motivating half of a collection mechanic.
    private func trophyTile(_ trophy: Trophy) -> some View {
        VStack(spacing: 6) {
            Text(trophy.emoji)
                .font(.system(size: 40))
                .grayscale(trophy.isUnlocked ? 0 : 1)
                .opacity(trophy.isUnlocked ? 1 : 0.35)

            Text(trophy.title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .padding(6)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.tileCornerRadius))
        .softShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trophy.title). \(trophy.detail). \(trophy.isUnlocked ? "Unlocked" : "Locked")")
    }
}
