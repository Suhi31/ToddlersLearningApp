//
//  HomeView.swift
//  ToddlerLearningApp
//
//  The activities come first. Previously Home opened with Letter of the Day,
//  My Progress and Today's Goal stacked above the games, which on a phone put
//  every activity below the fold — a child had to scroll past three progress
//  read-outs to reach the thing they came for.
//
//  Now: a compact header, then the grid of activities filling the screen, then
//  one quiet strip carrying Letter of the Day and today's stars. "My Progress"
//  is gone entirely — it is parent-facing and already on the parent dashboard,
//  and dropping it is what makes room for the grid.
//

import SwiftUI

struct HomeView: View {

    @State private var viewModel: HomeViewModel
    private let coordinator: AppCoordinator

    @State private var isMascotTapped = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Two roomy columns on a phone, three much larger ones on an iPad — the
    /// same rule covers every split-view width in between. See
    /// `AdaptiveLayout.activityTileMinimumWidth`.
    private var layout: AdaptiveLayout {
        AdaptiveLayout(size: .zero,
                       horizontalSizeClass: horizontalSizeClass,
                       verticalSizeClass: verticalSizeClass)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: layout.activityTileMinimumWidth),
                  spacing: AppSpacing.element)]
    }

    init(viewModel: HomeViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.element) {
                    header
                    activityGrid
                    footerStrip
                }
                .padding(AppSpacing.screen)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    coordinator.openParentArea()
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(AppFonts.body.weight(.bold))
                }
                .accessibilityLabel("Parents")
            }
        }
        .onAppear {
            // Returning to Home is a safe point to end the session on (spec F5).
            coordinator.checkTimeLimitAtSafePoint()
        }
        .onDisappear { viewModel.onDisappear() }
    }

    // MARK: - Header

    /// One row. The streak used to sit on its own line under the greeting;
    /// it now rides beside the star count so the header costs a single line.
    private var header: some View {
        HStack(spacing: AppSpacing.element) {
            mascotButton

            Text(viewModel.greeting)
                .font(AppFonts.heading)
                .foregroundStyle(AppColors.title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            HStack(spacing: AppSpacing.tight) {
                if viewModel.streak > 0 {
                    Text("🔥 \(viewModel.streak)")
                        .font(AppFonts.body)
                        .foregroundStyle(AppColors.subtitle)
                        .accessibilityLabel("\(viewModel.streak) day streak")
                }

                Text("⭐️ \(viewModel.starCount)")
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.title)
                    .accessibilityLabel("\(viewModel.starCount) stars")
            }
        }
    }

    /// Tapping the mascot gets a spoken greeting back — a small bit of
    /// responsiveness that makes the front page feel alive rather than static.
    private var mascotButton: some View {
        Button {
            viewModel.tapMascot()
            isMascotTapped = true
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                isMascotTapped = false
            }
        } label: {
            Text(viewModel.avatar)
                .font(.system(size: 44))
        }
        .buttonStyle(.plain)
        .scaleEffect(isMascotTapped ? 1.25 : 1.0)
        .rotationEffect(.degrees(isMascotTapped ? -8 : 0))
        .animation(.spring(response: 0.3, dampingFraction: 0.4), value: isMascotTapped)
        .accessibilityLabel("Say hi")
    }

    // MARK: - Activities

    private var activityGrid: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.element) {
            ActivityTile(title: "Learn Letters", emoji: "📖", color: AppColors.primary,
                         height: layout.activityTileHeight) {
                coordinator.startActivity(.learnAlphabet)
            }
            ActivityTile(title: "Trace Letters", emoji: "✏️", color: AppColors.primary,
                         height: layout.activityTileHeight) {
                coordinator.startActivity(.traceLetters)
            }
            ActivityTile(title: "Play a Game", emoji: "🎯", color: AppColors.success,
                         height: layout.activityTileHeight) {
                coordinator.startActivity(.quiz)
            }
            ActivityTile(title: "Learn Numbers", emoji: "🔢", color: AppColors.primary,
                         height: layout.activityTileHeight) {
                coordinator.startActivity(.learnNumbers)
            }
            ActivityTile(title: "Count & Find", emoji: "🍎", color: AppColors.success,
                         height: layout.activityTileHeight) {
                coordinator.startActivity(.numberQuiz)
            }
            ActivityTile(title: "Build the Word", emoji: "🧩", color: AppColors.primary,
                         height: layout.activityTileHeight) {
                coordinator.startActivity(.wordBuild)
            }
            ActivityTile(title: "Nursery Rhymes", emoji: "🎵", color: AppColors.success,
                         height: layout.activityTileHeight) {
                coordinator.startActivity(.rhymes)
            }
            ActivityTile(title: "My Rewards", emoji: "🏆", color: AppColors.warning,
                         badge: "\(viewModel.starCount) stars",
                         height: layout.activityTileHeight) {
                coordinator.startActivity(.rewards)
            }
        }
    }

    // MARK: - Footer

    /// Everything that used to compete with the games for the top of the
    /// screen, reduced to one quiet row: the day's letter on the left, today's
    /// star progress on the right. Spec F4 still wants the gentle daily goal
    /// visible on Home — it just shouldn't be the first thing a toddler sees.
    private var footerStrip: some View {
        HStack(spacing: AppSpacing.element) {
            letterOfDayPill
            Spacer(minLength: 0)
            goalReadout
        }
        .padding(AppSpacing.element)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }

    /// A fresh reason to open the app each day, and a one-tap way to hear a
    /// letter without diving into Learn Letters first.
    @ViewBuilder
    private var letterOfDayPill: some View {
        if let letter = viewModel.letterOfTheDay {
            let tint = AppColors.paletteColor(letter.colorIndex)

            Button {
                viewModel.tapLetterOfDay()
            } label: {
                HStack(spacing: AppSpacing.tight) {
                    Text(letter.uppercase)
                        .font(AppFonts.heading)
                        .foregroundStyle(AppColors.ink(on: tint))
                        .frame(width: 40, height: 40)
                        .background(tint)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    // No "LETTER OF THE DAY" eyebrow: in a strip this narrow it
                    // wrapped to two lines and pushed the whole footer off the
                    // bottom of the screen, and "Z is for Zebra" beside a
                    // letter tile already says what it is.
                    Text("\(letter.uppercase) is for \(letter.word)")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Image(systemName: "speaker.wave.2.fill")
                        .font(AppFonts.label.weight(.bold))
                        .foregroundStyle(tint)
                }
            }
            .buttonStyle(BouncyButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Letter of the day: \(letter.uppercase), for \(letter.word). Tap to hear it.")
        }
    }

    private var goalReadout: some View {
        VStack(alignment: .trailing, spacing: 2) {
            // Spec F5's soft heads-up. It lived on the old progress card; it
            // still belongs on Home, just not shouting.
            if let caption = viewModel.timeRemainingCaption {
                Text(caption)
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.warning)
            }

            Text(viewModel.dailyGoalCaption)
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.subtitle)
                .lineLimit(1)

            ProgressBar(value: viewModel.dailyGoalProgress,
                        tint: AppColors.warning,
                        height: 8)
                .frame(width: 96)
        }
        .accessibilityElement(children: .combine)
    }
}
