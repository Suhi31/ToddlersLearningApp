//
//  ContentTile.swift
//  ToddlerLearningApp
//
//  Replaces the byte-identical LetterTile and NumberTile, which differed only
//  in the string they displayed and the wording of their accessibility label.
//

import SwiftUI

/// What the Learn screens need from an item to page through it and render it
/// in the jump strip. Deliberately free of SwiftUI: `colorIndex` is resolved
/// to a real colour here in the view layer, same convention as `Letter`.
protocol BrowsableItem: Identifiable, Equatable {

    /// The glyph shown in a strip tile — "A", or "7".
    var tileLabel: String { get }

    /// How the item is named aloud and to VoiceOver — "Apple", or "Seven".
    var spokenName: String { get }

    var colorIndex: Int { get }
}

extension Letter: BrowsableItem {
    var tileLabel: String { uppercase }
    var spokenName: String { word }
}

extension NumberItem: BrowsableItem {
    var tileLabel: String { "\(id)" }
    var spokenName: String { name }
}

/// One tile in a Learn screen's jump strip.
struct ContentTile<Item: BrowsableItem>: View {

    let item: Item
    var mastery: MasteryLevel = .new
    var isHighlighted: Bool = false
    let action: () -> Void

    private var tint: Color { AppColors.paletteColor(item.colorIndex) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text(item.tileLabel)
                    .font(AppFonts.letterTile)
                    .foregroundStyle(isHighlighted ? AppColors.ink(on: tint) : AppColors.title)
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
        .accessibilityLabel("\(item.tileLabel), \(item.spokenName)")
        .accessibilityValue(mastery == .mastered ? "Mastered" : "")
    }
}

#Preview {
    HStack {
        ContentTile(item: AlphabetContent.letters[0], mastery: .mastered) {}
        ContentTile(item: AlphabetContent.letters[1], isHighlighted: true) {}
        ContentTile(item: NumberContent.numbers[2], isHighlighted: true) {}
    }
    .padding()
}
