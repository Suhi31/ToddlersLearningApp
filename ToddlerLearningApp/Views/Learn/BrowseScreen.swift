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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private func layout(_ size: CGSize) -> AdaptiveLayout {
        AdaptiveLayout(size: size,
                       horizontalSizeClass: horizontalSizeClass,
                       verticalSizeClass: verticalSizeClass)
    }

    private var layout: AdaptiveLayout {
        AdaptiveLayout(size: .zero, horizontalSizeClass: horizontalSizeClass)
    }

    private var stripColumns: [GridItem] {
        [GridItem(.adaptive(minimum: layout.stripTileMinimumWidth), spacing: 10)]
    }

    var body: some View {
        ZStack {
            GradientBackground()

            GeometryReader { geometry in
                content(in: geometry.size)
                    .padding(AppSpacing.screen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
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

    /// Side by side whenever the screen is genuinely *wider than it is tall* —
    /// on any device.
    ///
    /// Keying this off the size class put the stage and strip into two columns
    /// on an iPad in **portrait**, where there is plenty of height and the split
    /// only made both halves cramped. It also left a phone in **landscape**
    /// stacking a stage, a nav bar and a strip into ~330pt of height, which
    /// simply does not fit. Aspect ratio is the property that actually matters.
    private func usesSideBySide(_ size: CGSize) -> Bool {
        size.width > size.height
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if usesSideBySide(size) {
            HStack(alignment: .top, spacing: AppSpacing.section) {
                VStack(spacing: AppSpacing.element) {
                    if let current = viewModel.current {
                        stage(current)
                    }
                    navBar
                }
                .frame(maxWidth: .infinity)

                strip
                    .frame(maxWidth: .infinity)
            }
            // Both halves take the full height: pinned to the top the pair
            // occupied only the upper half of an iPad, and the strip was
            // squeezed to three columns.
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: AppSpacing.element) {
                if let current = viewModel.current {
                    stage(current)
                }
                navBar
                strip
                    // On a tall regular screen the stage card stretches to take
                    // the slack, so the strip is capped rather than splitting
                    // the height evenly with it.
                    .frame(maxHeight: layout.isRegular ? size.height * 0.38 : nil)
            }
        }
    }

    private var navBar: some View {
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
    }

    /// Jumping straight to an item matters — a child who wants "M" for their
    /// own name should not have to page through twelve others.
    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: stripColumns, spacing: 10) {
                    ForEach(viewModel.items) { item in
                        ContentTile(
                            item: item,
                            isHighlighted: item == viewModel.current
                        ) {
                            viewModel.jump(to: item)
                        }
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: viewModel.current) { _, newValue in
                guard let newValue else { return }
                withAnimation {
                    proxy.scrollTo(newValue.id, anchor: .center)
                }
            }
            .onAppear {
                if let current = viewModel.current {
                    proxy.scrollTo(current.id, anchor: .center)
                }
            }
        }
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var tint: Color { AppColors.paletteColor(item.colorIndex) }

    private var isShort: Bool { verticalSizeClass == .compact }

    /// Shrunk hard on a short screen — a 150pt glyph plus a word plus a button
    /// does not fit in the ~330pt a phone has in landscape.
    private var heroSize: CGFloat {
        if isShort { return 84 }
        return AdaptiveLayout(size: .zero,
                              horizontalSizeClass: horizontalSizeClass).heroGlyphSize
    }

    var body: some View {
        VStack(spacing: AppSpacing.tight) {
            Text(item.tileLabel)
                .font(.system(size: heroSize, weight: .heavy, design: .rounded))
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
        // Applied *before* `.background` so the card itself grows. Outside the
        // background it merely pads around an unchanged card and centres it in
        // the gap, which looks worse than not stretching at all.
        // Only stretch where there is slack; on a short screen the card has to
        // stay at its natural height or it pushes everything else off-screen.
        .frame(maxHeight: (horizontalSizeClass == .regular && !isShort) ? .infinity : nil)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }
}
