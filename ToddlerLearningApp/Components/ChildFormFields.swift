//
//  ChildFormFields.swift
//  ToddlerLearningApp
//
//  Shared by ChildPickerView (add a child) and SettingsView (edit the active
//  child) so the two forms can't drift apart.
//

import SwiftUI

struct ChildFormFields: View {

    @Binding var name: String
    @Binding var age: Int

    static let ageOptions: [(age: Int, animal: String)] = [
        (2, "🐥"), (3, "🐰"), (4, "🦁"), (5, "🐼")
    ]

    var body: some View {
        TextField("Name", text: $name)
            .foregroundStyle(AppColors.title)
            .textInputAutocapitalization(.words)

        Picker("Age", selection: $age) {
            ForEach(Self.ageOptions, id: \.age) { option in
                Text("\(option.animal)  \(option.age)").tag(option.age)
            }
        }
    }
}
