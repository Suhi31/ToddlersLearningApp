//
//  ChildPickerView.swift
//  ToddlerLearningApp
//
//  Spec F1, multi-child support. Presented from the parent dashboard, so it is
//  already behind the gate.
//

import SwiftData
import SwiftUI

struct ChildPickerView: View {

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ChildProfile.createdAt, order: .forward)
    private var children: [ChildProfile]

    private let coordinator: AppCoordinator

    @State private var isAdding = false
    @State private var newName = ""
    @State private var newAge = 3
    @State private var saveErrorMessage: String?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Children") {
                    ForEach(children) { child in
                        Button {
                            coordinator.switchTo(child)
                            dismiss()
                        } label: {
                            HStack {
                                Text(child.avatarEmoji).font(.system(size: 32))

                                VStack(alignment: .leading) {
                                    Text(child.name).font(AppFonts.body)
                                    Text("Age \(child.age) · \(child.masteredCount) mastered")
                                        .font(AppFonts.caption)
                                        .foregroundStyle(AppColors.subtitle)
                                }

                                Spacer()

                                if child.id == coordinator.activeChild?.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColors.success)
                                }
                            }
                        }
                        .foregroundStyle(AppColors.title)
                    }
                }

                if isAdding {
                    Section("New child") {
                        ChildFormFields(name: $newName, age: $newAge)

                        Button("Add") { addChild() }
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
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .alert("Couldn't Add", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        ), presenting: saveErrorMessage) { _ in
            Button("OK") { saveErrorMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    private func addChild() {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        do {
            try coordinator.dependencies.childProfileService.create(name: newName, age: newAge)
        } catch {
            // The parent is standing right here in this sheet — leaving the
            // failure to be discovered later in Settings meant "Add" silently
            // did nothing and the new row just never appeared.
            saveErrorMessage = "Couldn't add that child. Please try again."
            return
        }

        newName = ""
        newAge = 3
        isAdding = false
    }
}
