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
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ChildProfile.createdAt, order: .forward)
    private var children: [ChildProfile]

    private let coordinator: AppCoordinator

    @State private var isAdding = false
    @State private var newName = ""
    @State private var newAge = 3

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
    }

    private func addChild() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let avatar = ChildFormFields.ageOptions.first { $0.age == newAge }?.animal ?? "🐰"
        let child = ChildProfile(name: trimmed, age: newAge, avatarEmoji: avatar)
        modelContext.insert(child)
        try? modelContext.save()

        newName = ""
        newAge = 3
        isAdding = false
    }
}
