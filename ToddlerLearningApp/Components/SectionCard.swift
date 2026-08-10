//
//  SectionCard.swift
//  ToddlerLearningApp
//

import SwiftUI

/// A large, unmistakable entry point on the Home screen. Sized well past the
/// 44pt guideline because the target user has poor fine-motor control.
struct SectionCard: View {

    let title: String
    let subtitle: String
    let emoji: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.element) {
                Text(emoji)
                    .font(.system(size: 46))
                    .frame(width: 68, height: 68)
                    .background(color.opacity(0.22))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFonts.heading)
                        .foregroundStyle(AppColors.title)

                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.subtitle)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
            }
            .padding(AppSpacing.element)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
            .softShadow()
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

#Preview {
    SectionCard(title: "Learn Letters",
                subtitle: "Meet all the letters",
                emoji: "📖",
                color: AppColors.primary) {}
        .padding()
}
