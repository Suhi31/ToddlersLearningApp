//
//  RhymeDetailView.swift
//  ToddlerLearningApp
//
//  Artwork-led on purpose: the emoji is the part a pre-reader recognises, so it
//  leads and the words follow. The lyrics still carry the karaoke highlight for
//  whoever is singing along.
//

import SwiftUI

struct RhymeDetailView: View {

    @State private var viewModel: RhymeDetailViewModel
    private let coordinator: AppCoordinator

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(viewModel: RhymeDetailViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    private var tint: Color { AppColors.paletteColor(viewModel.rhyme.colorIndex) }

    /// A phone in landscape has ~330pt of height, and the transport row is not
    /// negotiable, so the words are what give way.
    private var isShort: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppSpacing.element) {
                artwork

                if let caption = linkageCaption {
                    Text(caption)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)
                }

                lyrics

                ProgressBar(value: viewModel.progress, tint: tint, height: 10)

                transport

                practiceLink

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.screen)
        }
        .childScreenTypeSize()
        .navigationTitle(viewModel.rhyme.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onSafeStoppingPoint = { coordinator.checkTimeLimitAtSafePoint() }
            // Autoplay must not roll on into the next rhyme once the daily
            // allowance is up.
            viewModel.canContinuePlaying = { !coordinator.showTimeUp }
            viewModel.onAppear()
        }
        .onDisappear { viewModel.onDisappear() }
        // "All done" is a full-screen cover, and a covered view does not
        // reliably receive `onDisappear` — without this the rhyme sings on
        // underneath it.
        .onChange(of: coordinator.showTimeUp) { _, isUp in
            if isUp { viewModel.stopForTimeUp() }
        }
    }

    private var artwork: some View {
        Text(viewModel.rhyme.emoji)
            .font(.system(size: isShort ? 56 : 96))
            .frame(width: isShort ? 88 : 148, height: isShort ? 88 : 148)
            .background(tint.opacity(0.18), in: Circle())
            // A second, wordless "it's playing" signal for a child who can't
            // read the button.
            .glow(tint, active: viewModel.isPlaying)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isPlaying)
            .accessibilityHidden(true)
    }

    /// Scrolls, and follows the singing: a full song runs to a couple of dozen
    /// lines — London Bridge builds itself back up five times — which no longer
    /// fits on a phone, and a child can't find the highlighted line if it's off
    /// the bottom of the card.
    private var lyrics: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.tight) {
                    ForEach(Array(viewModel.rhyme.lines.enumerated()), id: \.offset) { index, line in
                        let isHighlighted = viewModel.highlightedLineIndex == index

                        Text(line)
                            .font(AppFonts.body)
                            .foregroundStyle(isHighlighted ? AppColors.ink(on: tint) : AppColors.title)
                            .padding(.horizontal, AppSpacing.tight)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isHighlighted ? tint : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .animation(.easeInOut(duration: 0.2), value: isHighlighted)
                            // The highlight is otherwise conveyed by colour
                            // alone, which VoiceOver cannot see.
                            .accessibilityAddTraits(isHighlighted ? .isSelected : [])
                            .id(index)
                    }
                }
                .padding(AppSpacing.element)
                // The ForEach is keyed by offset, so line 3 of this rhyme and
                // line 3 of the next are the same SwiftUI identity: without a
                // per-rhyme id they cross-fade their text and keep the previous
                // song's scroll position.
                .id(viewModel.rhyme.id)
            }
            .onChange(of: viewModel.highlightedLineIndex) { _, line in
                guard let line else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(line, anchor: .center)
                }
            }
            .onChange(of: viewModel.rhyme.id) { _, _ in
                proxy.scrollTo(0, anchor: .top)
            }
        }
        .frame(maxHeight: isShort ? 140 : 300)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Words to \(viewModel.rhyme.title)")
    }

    /// Previous / play / next. `ArrowNavBar` is the app's paging idiom and
    /// brings 64pt targets and "Previous rhyme" / "Next rhyme" labels with it;
    /// the forward arrow greying out on the last rhyme is what tells a child
    /// they have reached the end.
    private var transport: some View {
        ArrowNavBar(canGoBack: viewModel.canGoPrevious,
                    canGoForward: viewModel.canGoNext,
                    itemNoun: "rhyme",
                    onBack: { viewModel.previous() },
                    onForward: { viewModel.next() }) {
            playButton
        }
    }

    /// Symbol only — "Play" and "Pause" are near-identical in length, so the
    /// words carry no state a child can read at a glance, while a 96pt icon
    /// flip does. Never `.disabled()`: see `RhymeDetailViewModel.togglePlayback`.
    private var playButton: some View {
        Button {
            viewModel.togglePlayback()
        } label: {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: isShort ? 32 : 42, weight: .heavy))
                .foregroundStyle(AppColors.ink(on: tint))
                .frame(width: isShort ? 72 : 96, height: isShort ? 72 : 96)
                .background(tint, in: Circle())
                .raisedShadow(color: tint)
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
        .accessibilityAddTraits(.startsMediaSession)
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
