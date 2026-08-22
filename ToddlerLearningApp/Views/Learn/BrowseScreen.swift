//
//  BrowseScreen.swift
//  ToddlerLearningApp
//
//  The shared chrome behind Learn Letters and Learn Numbers: the paging
//  arrows, the position caption, the jump strip, and the lifecycle/
//  safe-stopping-point wiring. `BrowsingViewModel<Item>` already generified
//  the behaviour; the two views had stayed verbatim copies of each other.
//
//  Only the stage — the big card above the arrows — genuinely differs between
//  the domains, so that is the one thing the caller supplies.
//

import SwiftUI

struct BrowseScreen<Item: BrowsableItem, Stage: View>: View {

    /// Held as a plain `let`, not `@State`: the owning screen creates and owns
    /// the view model, and `@Observable` means reading it here still tracks.
    let viewModel: BrowsingViewModel<Item>

    let coordinator: AppCoordinator
    let title: String

    /// Singular noun for the arrows' VoiceOver labels — "letter" or "number".
    let itemNoun: String

    @ViewBuilder let stage: (Item) -> Stage

    private let stripColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppSpacing.element) {
                if let current = viewModel.current {
                    stage(current)
                }

                ArrowNavBar(
                    canGoBack: viewModel.canGoBack,
                    canGoForward: viewModel.canGoForward,
                    itemNoun: itemNoun,
                    onBack: { viewModel.previous() },
                    onForward: { viewModel.next() }
                ) {
                    Text(viewModel.positionCaption)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)
                }
                .padding(.horizontal, AppSpacing.section)

                strip
            }
            .padding(AppSpacing.screen)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .childScreenTypeSize()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onSafeStoppingPoint = { coordinator.checkTimeLimitAtSafePoint() }
            viewModel.onAppear()
        }
        .onDisappear { viewModel.onDisappear() }
    }

    /// Jumping straight to an item matters — a child who wants "M" for their
    /// own name should not have to page through twelve others.
    private var strip: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: stripColumns, spacing: 10) {
                ForEach(viewModel.items) { item in
                    ContentTile(
                        item: item,
                        mastery: viewModel.mastery(for: item),
                        isHighlighted: item == viewModel.current
                    ) {
                        viewModel.jump(to: item)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxHeight: .infinity)
    }
}

/// The big card above the arrows. Hero glyph, name, illustration, a "hear it
/// again" pill and an optional tie-in to a rhyme — every part of which was
/// duplicated between the two Learn screens except the illustration itself.
struct BrowseStage<Item: BrowsableItem, Illustration: View>: View {

    let item: Item

    /// The rhyme this item ties to, if any — see `RhymeLinkage`.
    let linkedRhymeID: String?

    let onRepeat: () -> Void
    let coordinator: AppCoordinator

    @ViewBuilder let illustration: () -> Illustration

    private var tint: Color { AppColors.paletteColor(item.colorIndex) }

    var body: some View {
        VStack(spacing: AppSpacing.tight) {
            Text(item.tileLabel)
                .font(AppFonts.letterHero)
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: item)

            Text(item.spokenName)
                .font(AppFonts.heading)
                .foregroundStyle(AppColors.title)

            illustration()

            Button(action: onRepeat) {
                Label("Hear it again", systemImage: "speaker.wave.2.fill")
                    .font(AppFonts.body)
                    .foregroundStyle(AppColors.ink(on: tint))
                    .padding(.horizontal, AppSpacing.section)
                    .frame(height: 52)
                    .background(tint)
                    .clipShape(Capsule())
            }
            .buttonStyle(BouncyButtonStyle())
            .padding(.top, AppSpacing.tight)

            if let linkedRhymeID {
                Button {
                    coordinator.push(.rhymeDetail(linkedRhymeID))
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
}
