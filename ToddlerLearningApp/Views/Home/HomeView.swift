//
//  HomeView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct HomeView: View {

    @State private var viewModel: HomeViewModel
    private let coordinator: AppCoordinator

    @State private var isMascotTapped = false
    @State private var animatedProgress: Double = 0

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
                    letterOfDayCard
                    progressCard
                    dailyGoalCard

                    SectionCard(title: "Learn Letters",
                                subtitle: "Meet every letter and its sound",
                                emoji: "📖",
                                color: AppColors.primary) {
                        coordinator.push(.learnAlphabet)
                    }

                    SectionCard(title: "Trace Letters",
                                subtitle: "Practice writing with your finger",
                                emoji: "✏️",
                                color: AppColors.primary) {
                        coordinator.push(.traceLetters)
                    }

                    SectionCard(title: "Play a Game",
                                subtitle: "Find the letter and earn stars",
                                emoji: "🎯",
                                color: AppColors.success) {
                        coordinator.push(.quiz)
                    }

                    SectionCard(title: "Learn Numbers",
                                subtitle: "Count from one to ten",
                                emoji: "🔢",
                                color: AppColors.primary) {
                        coordinator.push(.learnNumbers)
                    }

                    SectionCard(title: "Count & Find",
                                subtitle: "Count how many and earn stars",
                                emoji: "🍎",
                                color: AppColors.success) {
                        coordinator.push(.numberQuiz)
                    }

                    SectionCard(title: "Build the Word",
                                subtitle: "Spell it and hear it come together",
                                emoji: "🧩",
                                color: AppColors.primary) {
                        coordinator.push(.wordBuild)
                    }

                    SectionCard(title: "Nursery Rhymes",
                                subtitle: "Sing along and learn",
                                emoji: "🎵",
                                color: AppColors.success) {
                        coordinator.push(.rhymes)
                    }

                    SectionCard(title: "My Rewards",
                                subtitle: "\(viewModel.starCount) stars collected",
                                emoji: "🏆",
                                color: AppColors.warning) {
                        coordinator.push(.rewards)
                    }
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
                        .font(.system(size: 16, weight: .bold))
                }
                .accessibilityLabel("Parents")
            }
        }
        .onAppear {
            // Returning to Home is a safe point to end the session on (spec F5).
            coordinator.checkTimeLimitAtSafePoint()
            animateProgressIn()
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.element) {
            mascotButton

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.greeting)
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.title)

                if viewModel.streak > 0 {
                    Text("🔥 \(viewModel.streak) day streak")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text("⭐️")
                Text("\(viewModel.starCount)")
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.title)
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
                .font(.system(size: 52))
        }
        .buttonStyle(.plain)
        .scaleEffect(isMascotTapped ? 1.25 : 1.0)
        .rotationEffect(.degrees(isMascotTapped ? -8 : 0))
        .animation(.spring(response: 0.3, dampingFraction: 0.4), value: isMascotTapped)
        .accessibilityLabel("Say hi")
    }

    /// A fresh reason to open the app each day, and a one-tap way to hear a
    /// letter without diving into Learn Letters first.
    @ViewBuilder
    private var letterOfDayCard: some View {
        if let letter = viewModel.letterOfTheDay {
            let tint = AppColors.paletteColor(letter.colorIndex)

            Button {
                viewModel.tapLetterOfDay()
            } label: {
                HStack(spacing: AppSpacing.element) {
                    Text(letter.uppercase)
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(tint)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.tileCornerRadius))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("LETTER OF THE DAY")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.subtitle)

                        Text("\(letter.uppercase) is for \(letter.word)")
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.title)
                    }

                    Spacer(minLength: 0)

                    Text(letter.emojis.first ?? "")
                        .font(.system(size: 34))

                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(tint)
                }
                .padding(AppSpacing.element)
                .background(tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                        .stroke(tint.opacity(0.45), lineWidth: 2)
                }
            }
            .buttonStyle(BouncyButtonStyle())
            .accessibilityLabel("Letter of the day: \(letter.uppercase), for \(letter.word). Tap to hear it.")
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            HStack {
                Text("My Progress")
                    .font(AppFonts.body)
                    .foregroundStyle(AppColors.title)

                Spacer()

                if let caption = viewModel.timeRemainingCaption {
                    Text(caption)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.warning)
                }
            }

            ProgressBar(value: animatedProgress)

            Text(viewModel.progressCaption)
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.subtitle)
        }
        .padding(AppSpacing.element)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }

    private var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            Text("🎯 Today's Goal")
                .font(AppFonts.body)
                .foregroundStyle(AppColors.title)

            ProgressBar(value: viewModel.dailyGoalProgress, tint: AppColors.warning)

            Text(viewModel.dailyGoalCaption)
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.subtitle)
        }
        .padding(AppSpacing.element)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
        .softShadow()
    }

    /// Starts at zero and fills to the real value just after appearing, so the
    /// bar visibly grows rather than snapping straight to its resting state.
    private func animateProgressIn() {
        animatedProgress = 0
        Task {
            try? await Task.sleep(for: .seconds(0.25))
            animatedProgress = viewModel.overallProgress
        }
    }
}
