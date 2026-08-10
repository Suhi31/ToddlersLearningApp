//
//  OnboardingViewModel.swift
//  ToddlerLearningApp
//

import Foundation
import SwiftData

@MainActor
@Observable
final class OnboardingViewModel {

    var name: String = ""
    var selectedAge: Int = 3

    var ageOptions: [(age: Int, animal: String)] { ChildFormFields.ageOptions }

    private let modelContext: ModelContext
    private let progressService: ProgressService

    init(modelContext: ModelContext, progressService: ProgressService) {
        self.modelContext = modelContext
        self.progressService = progressService
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

    /// Creates and persists the profile, seeding progress rows for the letters
    /// unlocked at this age so the dashboard has something to show immediately.
    func createProfile() -> ChildProfile {
        let child = ChildProfile(
            name: trimmedName,
            age: selectedAge,
            avatarEmoji: avatarForSelectedAge
        )
        modelContext.insert(child)

        for letter in AlphabetContent.unlockedLetters(forAge: selectedAge) {
            progressService.progress(for: child, letterID: letter.id)
        }

        try? modelContext.save()
        return child
    }
}
