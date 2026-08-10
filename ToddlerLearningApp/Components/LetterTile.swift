//
//  LetterTile.swift
//  ToddlerLearningApp
//

import SwiftUI

struct LetterTile: View {

    let letter: Letter
    var mastery: MasteryLevel = .new
    var isHighlighted: Bool = false
    let action: () -> Void

    private var tint: Color { AppColors.paletteColor(letter.colorIndex) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text(letter.uppercase)
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
        .accessibilityLabel("\(letter.uppercase), \(letter.word)")
    }
}

#Preview {
    HStack {
        LetterTile(letter: AlphabetContent.letters[0], mastery: .mastered) {}
        LetterTile(letter: AlphabetContent.letters[1], isHighlighted: true) {}
    }
    .padding()
}
