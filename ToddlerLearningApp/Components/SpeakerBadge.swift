//
//  SpeakerBadge.swift
//  ToddlerLearningApp
//
//  The small speaker on a game's picture, so it reads as something to tap
//  to hear the question again. Shared so every game marks it the same way.
//

import SwiftUI

struct SpeakerBadge: View {

    var body: some View {
        Image(systemName: "speaker.wave.2.fill")
            .font(AppFonts.label.weight(.bold))
            .foregroundStyle(AppColors.primary)
            .padding(6)
            .background(AppColors.card, in: Circle())
            .softShadow()
            .accessibilityHidden(true)
    }
}

extension View {

    /// Puts a `SpeakerBadge` on the bottom-trailing corner of this emoji
    /// picture. An emoji's line box runs well below the glyph itself, so the
    /// frame's corner is out in empty space; the badge is pulled in, in
    /// proportion to `emojiSize`, to sit on the picture.
    func speakerBadge(emojiSize: CGFloat, isHidden: Bool = false) -> some View {
        overlay(alignment: .bottomTrailing) {
            SpeakerBadge()
                .offset(x: -emojiSize * 0.03, y: -emojiSize * 0.21)
                .opacity(isHidden ? 0 : 1)
        }
    }
}
