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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The emoji medallion and chevron are a fixed ~100pt of the row's width.
    /// At accessibility text sizes that leaves so little for the label that
    /// "Learn Letters" hyphenates to "Learn Let-", so the card stacks instead
    /// and hands the full width to the text.
    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    private var layout: AnyLayout {
        isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.tight))
            : AnyLayout(HStackLayout(spacing: AppSpacing.element))
    }

    var body: some View {
        Button(action: action) {
            layout {
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

                if !isStacked {
                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(AppFonts.body.weight(.bold))
                        .foregroundStyle(color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
