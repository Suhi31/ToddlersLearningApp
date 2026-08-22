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

    /// The dashboard is prose a parent may genuinely need at the largest
    /// sizes, so it is deliberately not capped by `childScreenTypeSize()`.
    /// The cost is that its side-by-side rows have to reflow themselves —
    /// at AX5 an HStack squeezes "Mastered 0" down to "Mast/ered 0".
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let masteryColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    /// Horizontal normally, stacked once text is large enough that a row of
    /// items can no longer share the width.
    private var adaptiveRow: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.tight))
            : AnyLayout(HStackLayout(spacing: AppSpacing.element))
    }

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

                    ForEach(viewModel.summaries) { summary in
                        masterySection(summary)
                        practiceSection(summary)
                    }

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
            adaptiveRow {
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

                if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
                       spacing: 2) {
                    Text("⭐️ \(viewModel.totalStars)")
                        .font(AppFonts.body)
                    Text("🔥 \(viewModel.streak) day streak")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)
                }
            }
        }
    }

    private func masterySection(_ summary: ParentDashboardViewModel.DomainSummary) -> some View {
        card {
            VStack(alignment: .leading, spacing: AppSpacing.tight) {
                sectionTitle(summary.title)

                adaptiveRow {
                    legend(color: AppColors.success, label: "Mastered \(summary.masteredCount)")
                    legend(color: AppColors.warning, label: "Learning \(summary.learningCount)")
                    legend(color: AppColors.disabledBackground, label: "New \(summary.notStartedCount)")
                }

                LazyVGrid(columns: masteryColumns, spacing: 8) {
                    ForEach(summary.cells) { cell in
                        let fill = color(for: cell.mastery)
                        Text(cell.label)
                            // Fixed on purpose: this is a colour-coded matrix,
                            // and the meaning is carried by the cell colour and
                            // the accessibility label below, not by the glyph
                            // size. Scaling it bursts the grid without telling
                            // the reader anything more.
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.ink(on: fill))
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(fill)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel("\(cell.label): \(cell.mastery.title)")
                    }
                }
            }
        }
    }

    /// Surfaced so a parent has something concrete to do offline, which is what
    /// the research says actually moves the needle.
    @ViewBuilder
    private func practiceSection(_ summary: ParentDashboardViewModel.DomainSummary) -> some View {
        if !summary.needsPractice.isEmpty {
            card {
                VStack(alignment: .leading, spacing: AppSpacing.tight) {
                    sectionTitle(summary.practiceTitle)

                    Text(summary.practiceAdvice)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)

                    HStack(spacing: AppSpacing.tight) {
                        ForEach(summary.needsPractice, id: \.self) { label in
                            Text(label)
                                .font(AppFonts.button.weight(.heavy))
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

                adaptiveRow {
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

                    Text(entry.date.formatted(.dateTime.weekday(.narrow)))
                        .font(AppFonts.label)
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
                    .font(AppFonts.label.weight(.regular))
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
                .font(AppFonts.label)
                .foregroundStyle(AppColors.subtitle)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func color(for mastery: MasteryLevel) -> Color {
        switch mastery {
        case .mastered: AppColors.success
        case .learning: AppColors.warning
        case .new: AppColors.disabledBackground
        }
    }

}
