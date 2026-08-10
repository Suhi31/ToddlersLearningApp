//
//  ToddlerLearningAppApp.swift
//  ToddlerLearningApp
//
//  Created by Nusrat Jahan on 7/8/26.
//

import SwiftData
import SwiftUI

@main
struct ToddlerLearningAppApp: App {

    private let modelContainer: ModelContainer
    @State private var dependencies: AppDependencies

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: ChildProfile.self, LetterProgress.self, NumberProgress.self, SessionRecord.self
            )
        } catch {
            // Without a store there is no app — every screen is progress-driven.
            fatalError("Failed to create the SwiftData container: \(error)")
        }

        self.modelContainer = container
        _dependencies = State(initialValue: AppDependencies(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                // Every color in the app (AppColors, GradientBackground) is a
                // fixed pastel palette with no dark variant — most screens
                // never visibly change in Dark Mode, but plain system
                // List/Form screens (ChildPickerView, SettingsView) do adapt
                // their row backgrounds, which then clashes with that fixed
                // text/card palette (e.g. dark-navy text becoming unreadable
                // on a dark row). Pinning the whole app to light keeps every
                // screen consistent with the one theme it's actually designed for.
                .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
    }
}
