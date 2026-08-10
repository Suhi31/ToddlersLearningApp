//
//  AgeCard.swift
//  ToddlerLearningApp
//

import SwiftUI

struct AgeCard: View {

    let age: Int
    let animal: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.tight) {
                Text(animal)
                    .font(.system(size: 46))

                Text("\(age)")
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.title)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                    .stroke(AppColors.primary, lineWidth: isSelected ? 4 : 0)
            }
            .softShadow()
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Age \(age)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    HStack {
        AgeCard(age: 2, animal: "🐥", isSelected: false) {}
        AgeCard(age: 3, animal: "🐰", isSelected: true) {}
    }
    .padding()
}
