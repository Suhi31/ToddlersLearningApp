//
//  ChildProfileService.swift
//  ToddlerLearningApp
//
//  Creating a child profile happened in three places — onboarding, the
//  switch-child sheet, and settings — with three slightly different
//  implementations and three different ideas about error handling.
//

import Foundation
import SwiftData

@MainActor
final class ChildProfileService {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Creates and persists a profile.
    ///
    /// Deliberately does *not* seed `LetterProgress` rows the way onboarding
    /// used to: `ProgressService.progress(for:letterID:)` creates them lazily
    /// on first encounter, and the dashboard's counts derive from the unlocked
    /// content set rather than from stored rows, so the seeding loop only ever
    /// wrote rows nothing read.
    @discardableResult
    func create(name: String, age: Int) throws -> ChildProfile {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatar = ChildFormFields.ageOptions.first { $0.age == age }?.animal ?? "🐰"

        let child = ChildProfile(name: trimmed, age: age, avatarEmoji: avatar)
        context.insert(child)

        do {
            try context.save()
        } catch {
            // Leave no half-inserted profile behind for the next save to pick up.
            context.delete(child)
            throw error
        }
        return child
    }
}
