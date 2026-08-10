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

    /// Snapshot of each child's saved values, so edits made live to the
    /// `@Bindable` model (which update the UI immediately but aren't
    /// persisted yet) can be compared against something to know whether
    /// there's anything to save.
    @State private var savedValues: [UUID: (name: String, age: Int)] = [:]

    @State private var didSaveAll = false
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

                PrimaryButton(
                    title: didSaveAll ? "Saved! ✓" : "Save changes",
                    color: didSaveAll ? AppColors.success : AppColors.primary,
                    isEnabled: canSaveAll
                ) {
                    saveAll()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.vertical, AppSpacing.tight)

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
        .onAppear { syncSavedValues() }
        .onChange(of: children.map(\.id)) { _, _ in syncSavedValues() }
        .alert("Couldn't Save", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        ), presenting: saveErrorMessage) { _ in
            Button("OK") { saveErrorMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Save

    private var isDirty: Bool {
        children.contains { child in
            let saved = savedValues[child.id]
            return saved?.name != child.name || saved?.age != child.age
        }
    }

    private var canSaveAll: Bool {
        isDirty && children.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func saveAll() {
        guard canSaveAll else { return }

        for child in children {
            let trimmed = child.name.trimmingCharacters(in: .whitespaces)
            if trimmed != child.name { child.name = trimmed }
        }

        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = "Couldn't save your changes. Please try again."
            return
        }

        focusedChildID = nil
        syncSavedValues()

        didSaveAll = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didSaveAll = false
        }
    }

    private func syncSavedValues() {
        let currentIDs = Set(children.map(\.id))
        savedValues = savedValues.filter { currentIDs.contains($0.key) }
        for child in children {
            savedValues[child.id] = (child.name, child.age)
        }
    }

    // MARK: - Add

    private func addChild() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let avatar = ChildFormFields.ageOptions.first { $0.age == newAge }?.animal ?? "🐰"
        let child = ChildProfile(name: trimmed, age: newAge, avatarEmoji: avatar)
        modelContext.insert(child)

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(child)
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

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            HStack {
                Text(child.avatarEmoji)
                    .font(.system(size: 28))

                TextField("Name", text: $child.name)
                    .foregroundStyle(AppColors.title)
                    .textInputAutocapitalization(.words)
                    .focused(focusedChildID, equals: child.id)

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
}
