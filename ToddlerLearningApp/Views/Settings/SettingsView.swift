//
//  SettingsView.swift
//  ToddlerLearningApp
//
//  Manages every child profile in one place — add a sibling, fix a
//  name/age typo, or remove a child entirely — rather than splitting
//  that across the switch-child sheet.
//

import SwiftData
import SwiftUI

struct SettingsView: View {

    @Query(sort: \ChildProfile.createdAt, order: .forward)
    private var children: [ChildProfile]

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SpeechService.soundEnabledKey) private var isSoundEnabled = true

    private let coordinator: AppCoordinator

    @State private var isAdding = false
    @State private var newName = ""
    @State private var newAge = 3

    @FocusState private var focusedChildID: UUID?
    @State private var saveErrorMessage: String?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        Form {
            Section("Children") {
                ForEach(children) { child in
                    ChildEditRow(
                        child: child,
                        isActive: child.id == coordinator.activeChild?.id,
                        focusedChildID: $focusedChildID
                    )
                }
                .onDelete(perform: delete)

                if isAdding {
                    ChildFormFields(name: $newName, age: $newAge)

                    HStack {
                        Button("Cancel", role: .cancel) { cancelAdding() }
                            .buttonStyle(.borderless)
                        Spacer()
                        Button("Add") { addChild() }
                            .buttonStyle(.borderless)
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add a child", systemImage: "plus.circle.fill")
                    }
                }
            }

            Section("Sound") {
                Toggle("Spoken letters & sounds", isOn: $isSoundEnabled)
            }

            Section {
                Text("Progress and settings are stored on this device only.")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.subtitle)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .alert("Couldn't Save", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        ), presenting: saveErrorMessage) { _ in
            Button("OK") { saveErrorMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Add

    private func addChild() {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        do {
            try coordinator.dependencies.childProfileService.create(name: newName, age: newAge)
        } catch {
            saveErrorMessage = "Couldn't add that child. Please try again."
            return
        }

        cancelAdding()
    }

    private func cancelAdding() {
        newName = ""
        newAge = 3
        isAdding = false
    }

    // MARK: - Delete

    /// Deleting the active child needs to switch away (or clear it, if this
    /// was the last profile), but that navigation-affecting step now happens
    /// *after* the model mutation is fully committed, not before.
    ///
    /// NOTE: the previous version of this function did the navigation switch
    /// first and deferred the actual `modelContext.delete` + `save()` to a
    /// `Task` a run-loop turn later — that ordering is the likely source of
    /// an intermittent crash reported across several prior attempts at this
    /// function. Switching away (or clearing the active child, which pops
    /// the whole `NavigationStack` back to onboarding) tears down the very
    /// destination hosting this `@Query`-bound `ForEach`/`.onDelete` list
    /// *before* the row it's mid-animating out has actually been removed
    /// from the model — a known class of SwiftData/SwiftUI crash. Deleting
    /// and saving synchronously first, while this view is still fully
    /// present, lets the List's delete animation and the `@Query` refresh
    /// settle normally (same as any other row deletion) before anything
    /// navigation-related happens.
    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { children[$0] }
        let deletedIDs = Set(toDelete.map(\.id))
        let wasActiveChildDeleted = toDelete.contains { $0.id == coordinator.activeChild?.id }
        let replacement = children.first { !deletedIDs.contains($0.id) }

        for child in toDelete {
            modelContext.delete(child)
        }

        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = "Couldn't remove that profile. Please try again."
            return
        }

        guard wasActiveChildDeleted else { return }
        if let replacement {
            coordinator.switchTo(replacement)
        } else {
            coordinator.clearActiveChild()
        }
    }
}

private struct ChildEditRow: View {

    @Bindable var child: ChildProfile
    let isActive: Bool
    var focusedChildID: FocusState<UUID?>.Binding

    /// The name as it stood when this field gained focus. `child.name` is a
    /// live `@Bindable` binding — SwiftData autosaves every keystroke, there
    /// is no separate "Save changes" step — so this exists only to have
    /// something to restore to if the field is left empty, rather than
    /// silently persisting a blank name.
    @State private var nameBeforeEditing = ""

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            HStack {
                Text(child.avatarEmoji)
                    .font(.system(size: 28))

                TextField("Name", text: $child.name)
                    .foregroundStyle(AppColors.title)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused(focusedChildID, equals: child.id)
                    .onChange(of: focusedChildID.wrappedValue) { previous, current in
                        if current == child.id {
                            nameBeforeEditing = child.name
                        } else if previous == child.id {
                            commitName()
                        }
                    }

                if isActive {
                    Text("Active")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.success)
                }
            }

            Picker("Age", selection: $child.age) {
                ForEach(ChildFormFields.ageOptions, id: \.age) { option in
                    Text("\(option.animal)  \(option.age)").tag(option.age)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: child.age) { _, newAge in
                child.avatarEmoji = ChildFormFields.ageOptions.first { $0.age == newAge }?.animal ?? child.avatarEmoji
            }
        }
        .padding(.vertical, AppSpacing.tight)
    }

    /// Trims trailing/leading whitespace on losing focus, and restores the
    /// pre-edit name if that leaves nothing — a blank name would otherwise
    /// persist via autosave rather than just look temporarily empty.
    private func commitName() {
        let trimmed = child.name.trimmingCharacters(in: .whitespaces)
        child.name = trimmed.isEmpty ? nameBeforeEditing : trimmed
    }
}
