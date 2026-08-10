//
//  ParentGateView.swift
//  ToddlerLearningApp
//
//  Spec F3. Apple's Kids Category requires a gate before settings, external
//  links or purchases. A two-digit multiplication is beyond a preschooler but
//  trivial for an adult, which is exactly the bar this needs to clear.
//

import SwiftUI

struct ParentGateView: View {

    private let coordinator: AppCoordinator

    @State private var multiplicand = Int.random(in: 4...9)
    @State private var multiplier = Int.random(in: 6...12)
    @State private var entry = ""
    @State private var showError = false

    @FocusState private var isFocused: Bool

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    private var expectedAnswer: Int { multiplicand * multiplier }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: AppSpacing.section) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.primary)

                VStack(spacing: AppSpacing.tight) {
                    Text("Parents only")
                        .font(AppFonts.hero)
                        .foregroundStyle(AppColors.title)

                    Text("Answer to continue")
                        .font(AppFonts.body)
                        .foregroundStyle(AppColors.subtitle)
                }

                Text("\(multiplicand) × \(multiplier) = ?")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.title)

                TextField("Answer", text: $entry)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.title)
                    .focused($isFocused)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
                    .softShadow()

                if showError {
                    Text("Not quite — try again")
                        .font(AppFonts.caption)
                        .foregroundStyle(.red)
                }

                PrimaryButton(title: "Continue", isEnabled: !entry.isEmpty) {
                    submit()
                }
                .frame(maxWidth: 260)

                Spacer()
            }
            .padding(AppSpacing.screen)
            .padding(.top, AppSpacing.section)
        }
        .navigationTitle("Parents")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = true }
    }

    private func submit() {
        guard Int(entry) == expectedAnswer else {
            showError = true
            entry = ""
            // A fresh problem on failure prevents brute-forcing one answer.
            multiplicand = Int.random(in: 4...9)
            multiplier = Int.random(in: 6...12)
            return
        }

        isFocused = false
        coordinator.parentGatePassed()
    }
}
