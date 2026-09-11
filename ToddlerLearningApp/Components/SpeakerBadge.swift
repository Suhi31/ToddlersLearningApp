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
