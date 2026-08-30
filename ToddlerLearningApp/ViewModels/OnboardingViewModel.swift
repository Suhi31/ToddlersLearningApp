//
//  OnboardingViewModel.swift
//  ToddlerLearningApp
//

import Foundation

@MainActor
@Observable
final class OnboardingViewModel {

    var name: String = ""
    var selectedAge: Int = 3

    var ageOptions: [(age: Int, animal: String)] { ChildFormFields.ageOptions }

    private let childProfileService: ChildProfileService

    init(childProfileService: ChildProfileService) {
        self.childProfileService = childProfileService
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canContinue: Bool { !trimmedName.isEmpty }

    var greeting: String {
        trimmedName.isEmpty ? "Hi friend! 👋" : "Hi \(trimmedName)! 👋"
    }

    var avatarForSelectedAge: String {
        ageOptions.first { $0.age == selectedAge }?.animal ?? "🐰"
    }

    /// Creates and persists the profile. Throws if the store refuses the
    /// write, so the caller can tell the parent rather than "Let's Play!"
    /// silently doing nothing and leaving them stuck on onboarding with no
    /// idea why.
    func createProfile() throws -> ChildProfile {
        try childProfileService.create(name: trimmedName, age: selectedAge)
    }
}
