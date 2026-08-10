//
//  NumberTile.swift
//  ToddlerLearningApp
//
//  Numbers-domain twin of LetterTile.
//

import SwiftUI

struct NumberTile: View {

    let number: NumberItem
    var mastery: MasteryLevel = .new
    var isHighlighted: Bool = false
    let action: () -> Void

    private var tint: Color { AppColors.paletteColor(number.colorIndex) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text("\(number.id)")
                    .font(AppFonts.letterTile)
                    .foregroundStyle(isHighlighted ? .white : AppColors.title)
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .background(isHighlighted ? tint : tint.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.tileCornerRadius))
                    .glow(tint, active: isHighlighted)

                if mastery == .mastered {
                    Text("⭐️")
                        .font(.system(size: 15))
                        .padding(5)
                }
            }
            .scaleEffect(isHighlighted ? 1.12 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isHighlighted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(number.id), \(number.name)")
    }
}

#Preview {
    HStack {
        NumberTile(number: NumberContent.numbers[0], mastery: .mastered) {}
        NumberTile(number: NumberContent.numbers[1], isHighlighted: true) {}
    }
    .padding()
}
