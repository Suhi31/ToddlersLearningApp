//
//  ParentDashboardView.swift
//  ToddlerLearningApp
//
//  Spec F3. Reachable only via ParentGateView.
//

import SwiftUI

struct ParentDashboardView: View {

    @State private var viewModel: ParentDashboardViewModel
    private let coordinator: AppCoordinator

    private let masteryColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    init(viewModel: ParentDashboardViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.element) {
                    summarySection
                    masterySection
                    practiceSection
                    numbersMasterySection
                    numbersPracticeSection
                    screenTimeSection
                    limitSection
                    privacyNote
                }
                .padding(AppSpacing.screen)
            }
        }
        .navigationTitle("Parent Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Switch child") {
                    coordinator.sheet = .switchChild
                }
                .font(AppFonts.caption)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    coordinator.push(.settings)
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        card {
            HStack {
                Text(viewModel.child.avatarEmoji)
                    .font(.system(size: 44))

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.child.name)
                        .font(AppFonts.heading)
                        .foregroundStyle(AppColors.title)
                    Text("Age \(viewModel.child.age)")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("⭐️ \(viewModel.totalStars)")
                        .font(AppFonts.body)
                    Text("🔥 \(viewModel.streak) day streak")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)
                }
            }
        }
    }

    private var masterySection: some View {
        card {
            VStack(alignment: .leading, spacing: AppSpacing.tight) {
                sectionTitle("Letter mastery")

                HStack(spacing: AppSpacing.element) {
                    legend(color: AppColors.success, label: "Mastered \(viewModel.masteredCount)")
                    legend(color: AppColors.warning, label: "Learning \(viewModel.learningCount)")
                    legend(color: AppColors.disabledBackground, label: "New \(viewModel.notStartedCount)")
                }

                LazyVGrid(columns: masteryColumns, spacing: 8) {
                    ForEach(viewModel.letters) { letter in
                        Text(letter.uppercase)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(color(for: viewModel.mastery(for: letter)))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel("\(letter.uppercase): \(viewModel.mastery(for: letter).title)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var practiceSection: some View {
        if !viewModel.lettersNeedingPractice.isEmpty {
            card {
                VStack(alignment: .leading, spacing: AppSpacing.tight) {
                    sectionTitle("Worth practising together")

                    Text("These come up wrong most often. Pointing them out in books or on signs helps more than extra screen time.")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)

                    HStack(spacing: AppSpacing.tight) {
                        ForEach(viewModel.lettersNeedingPractice) { letter in
                            Text(letter.uppercase)
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(AppColors.title)
                                .frame(width: 44, height: 44)
                                .background(AppColors.warning.opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    private var numbersMasterySection: some View {
        card {
            VStack(alignment: .leading, spacing: AppSpacing.tight) {
                sectionTitle("Number mastery")

                HStack(spacing: AppSpacing.element) {
                    legend(color: AppColors.success, label: "Mastered \(viewModel.masteredNumberCount)")
                    legend(color: AppColors.warning, label: "Learning \(viewModel.learningNumberCount)")
                    legend(color: AppColors.disabledBackground, label: "New \(viewModel.notStartedNumberCount)")
                }

                LazyVGrid(columns: masteryColumns, spacing: 8) {
                    ForEach(viewModel.numbers) { number in
                        Text("\(number.id)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(color(for: viewModel.mastery(for: number)))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel("\(number.id): \(viewModel.mastery(for: number).title)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var numbersPracticeSection: some View {
        if !viewModel.numbersNeedingPractice.isEmpty {
            card {
                VStack(alignment: .leading, spacing: AppSpacing.tight) {
                    sectionTitle("Numbers worth practising together")

                    Text("These come up wrong most often. Counting things around the house helps more than extra screen time.")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)

                    HStack(spacing: AppSpacing.tight) {
                        ForEach(viewModel.numbersNeedingPractice) { number in
                            Text("\(number.id)")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(AppColors.title)
                                .frame(width: 44, height: 44)
                                .background(AppColors.warning.opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    private var screenTimeSection: some View {
        card {
            VStack(alignment: .leading, spacing: AppSpacing.tight) {
                sectionTitle("Screen time")

                HStack {
                    stat("\(viewModel.minutesToday)m", "today")
                    stat("\(viewModel.weeklyMinutes)m", "this week")
                    stat("\(viewModel.sessionCount)", "sessions")
                }

                weeklyChart
            }
        }
    }

    private var weeklyChart: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(viewModel.weeklyTotals.enumerated()), id: \.offset) { _, entry in
                let minutes = entry.seconds / 60
                // Scaled against a 60-minute reference so bars stay comparable
                // day to day rather than re-normalising to the week's maximum.
                let height = min(CGFloat(minutes) / 60 * 70, 70)

                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.primary.opacity(minutes > 0 ? 0.8 : 0.15))
                        .frame(height: max(height, 4))

                    Text(Self.weekdayFormatter.string(from: entry.date))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.subtitle)
                }
            }
        }
        .frame(height: 90, alignment: .bottom)
    }

    private var limitSection: some View {
        card {
            VStack(alignment: .leading, spacing: AppSpacing.tight) {
                sectionTitle("Daily limit")

                Text("The app finishes the current activity, then shows a friendly goodbye. It never cuts off mid-question.")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.subtitle)

                Picker("Daily limit", selection: Binding(
                    get: { viewModel.dailyLimitMinutes },
                    set: { viewModel.dailyLimitMinutes = $0 }
                )) {
                    ForEach(viewModel.limitOptions, id: \.self) { minutes in
                        Text(viewModel.limitLabel(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.segmented)

                Text("The AAP suggests about an hour a day of high-quality screen time for ages 2–5.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.subtitle)
            }
        }
    }

    private var privacyNote: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Label("Privacy", systemImage: "hand.raised.fill")
                    .font(AppFonts.body)
                    .foregroundStyle(AppColors.title)

                Text("All progress is stored on this device only. There are no ads, no accounts, no analytics, and nothing is ever uploaded.")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.subtitle)
            }
        }
    }

    // MARK: - Building blocks

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(AppSpacing.element)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
            .softShadow()
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(AppFonts.body)
            .foregroundStyle(AppColors.title)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFonts.heading)
                .foregroundStyle(AppColors.title)
            Text(label)
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.subtitle)
        }
        .frame(maxWidth: .infinity)
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.subtitle)
        }
    }

    private func color(for mastery: MasteryLevel) -> Color {
        switch mastery {
        case .mastered: AppColors.success
        case .learning: AppColors.warning
        case .new: AppColors.disabledBackground
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter
    }()
}
