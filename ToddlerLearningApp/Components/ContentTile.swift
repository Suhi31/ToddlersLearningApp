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
    var isHighlighted: Bool = false
    let action: () -> Void

    private var tint: Color { AppColors.paletteColor(item.colorIndex) }

    // No mastery star. Tiles used to show ⭐️ on letters the child had mastered
    // in Find the Letter, but on a screen for exploring they read as a mystery
    // reward with no explanation. Mastery is still tracked and still shown on
    // the parent dashboard; it just isn't surfaced to the child here.
    var body: some View {
        Button(action: action) {
            Text(item.tileLabel)
                .font(AppFonts.letterTile)
                .foregroundStyle(isHighlighted ? AppColors.ink(on: tint) : AppColors.title)
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .background(isHighlighted ? tint : tint.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.tileCornerRadius))
                .glow(tint, active: isHighlighted)
                .scaleEffect(isHighlighted ? 1.12 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isHighlighted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.tileLabel), \(item.spokenName)")
    }
}

#Preview {
    HStack {
        ContentTile(item: AlphabetContent.letters[0]) {}
        ContentTile(item: AlphabetContent.letters[1], isHighlighted: true) {}
        ContentTile(item: NumberContent.numbers[2], isHighlighted: true) {}
    }
    .padding()
}
