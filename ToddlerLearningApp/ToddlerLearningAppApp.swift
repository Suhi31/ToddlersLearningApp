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

    /// True when the on-disk store couldn't be opened and the app fell back to
    /// an in-memory one. Progress made this session will not survive relaunch,
    /// which is worth telling the parent rather than silently losing.
    private let isUsingFallbackStore: Bool

    @State private var dependencies: AppDependencies

    init() {
        let (container, isFallback) = Self.makeContainer()
        self.modelContainer = container
        self.isUsingFallbackStore = isFallback
        _dependencies = State(initialValue: AppDependencies(modelContext: container.mainContext))
    }

    /// A corrupt store or a failed migration used to be a `fatalError` here,
    /// which turns a recoverable data problem into a permanent launch crash —
    /// the app never opens again and a parent has no way out short of
    /// deleting it. Falling back to an in-memory container keeps every screen
    /// working and lets the UI say what happened.
    private static func makeContainer() -> (ModelContainer, Bool) {
        let schema = Schema([
            ChildProfile.self, LetterProgress.self, NumberProgress.self, SessionRecord.self
        ])

        do {
            return (try ModelContainer(for: schema), false)
        } catch {
            print("Persistent store unavailable, falling back to in-memory: \(error)")
        }

        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try ModelContainer(for: schema, configurations: configuration), true)
        } catch {
            // An in-memory container failing means the schema itself is
            // invalid — a programmer error, not a runtime condition.
            preconditionFailure("Failed to create even an in-memory container: \(error)")
        }
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
                .overlay(alignment: .top) {
                    if isUsingFallbackStore {
                        StorageWarningBanner()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
