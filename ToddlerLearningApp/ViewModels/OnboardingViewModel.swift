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

    /// Creates and persists the profile. Returns `nil` only if the store
    /// refuses the write, in which case the caller stays on onboarding rather
    /// than navigating into a session with no child behind it.
    func createProfile() -> ChildProfile? {
        try? childProfileService.create(name: trimmedName, age: selectedAge)
    }
}
