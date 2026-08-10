//
//  OnboardingView.swift
//  ToddlerLearningApp
//

import SwiftUI

struct OnboardingView: View {

    @State private var viewModel: OnboardingViewModel
    private let coordinator: AppCoordinator

    @FocusState private var isNameFocused: Bool

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(viewModel: OnboardingViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.section) {

                    MascotView(emoji: viewModel.avatarForSelectedAge)
                        .padding(.top, AppSpacing.section)

                    VStack(spacing: AppSpacing.tight) {
                        Text(viewModel.greeting)
                            .font(AppFonts.hero)
                            .foregroundStyle(AppColors.title)

                        Text("Let's learn through fun and play!")
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.subtitle)
                    }
                    .multilineTextAlignment(.center)

                    nameField
                    agePicker

                    PrimaryButton(
                        title: "🌟 Let's Play!",
                        isEnabled: viewModel.canContinue
                    ) {
                        isNameFocused = false
                        coordinator.start(with: viewModel.createProfile())
                    }

                    // Set expectations with the parent before anything is stored.
                    Text("Everything stays on this device. No ads, no accounts.")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, AppSpacing.section)
                }
                .padding(AppSpacing.screen)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            Text("What's your name?")
                .font(AppFonts.heading)
                .foregroundStyle(AppColors.title)

            TextField("Enter your name", text: $viewModel.name)
                .font(AppFonts.body)
                .foregroundStyle(AppColors.title)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isNameFocused)
                .padding()
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
                .softShadow()
        }
    }

    private var agePicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.element) {
            Text("How old are you?")
                .font(AppFonts.heading)
                .foregroundStyle(AppColors.title)

            LazyVGrid(columns: columns, spacing: AppSpacing.element) {
                ForEach(viewModel.ageOptions, id: \.age) { option in
                    AgeCard(
                        age: option.age,
                        animal: option.animal,
                        isSelected: viewModel.selectedAge == option.age
                    ) {
                        viewModel.selectedAge = option.age
                    }
                }
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    return OnboardingView(
        viewModel: OnboardingViewModel(
            modelContext: dependencies.modelContext,
            progressService: dependencies.progressService
        ),
        coordinator: AppCoordinator(dependencies: dependencies)
    )
}
