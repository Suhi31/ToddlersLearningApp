//
//  ActivityTile.swift
//  ToddlerLearningApp
//
//  One activity on the Home grid. Replaces `SectionCard`, whose full-width
//  row — small leading medallion, title, subtitle, trailing chevron — was a
//  layout for someone who reads. A pre-reader picks an activity out by picture
//  and colour, so here the emoji is the largest thing in the tile and the
//  label sits under it as a cue for the adult nearby.
//
//  No chevron: eight of them pointing at nothing in a grid is noise, and the
//  whole tile is the tap target anyway.
//

import SwiftUI

struct ActivityTile: View {

    let title: String
    let emoji: String
    let color: Color

    /// Optional badge, e.g. the star count on My Rewards.
    var badge: String? = nil

    /// Set by the grid from `AdaptiveLayout` — a phone wants eight compact
    /// tiles above the fold, an iPad wants far fewer, far larger ones.
    var height: CGFloat = 120

    /// Last, so a trailing closure matches it forwards — declared before
    /// `badge` it bound backwards past the default and Swift warns.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.tight) {
                Text(emoji)
                    .font(.system(size: height * 0.37))

                Text(title)
                    .font(AppFonts.body.weight(.bold))
                    .foregroundStyle(AppColors.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                if let badge {
                    Text(badge)
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.subtitle)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            // Sized so four rows of two plus the header and footer strip all
            // fit above the fold on a modern phone — the whole point of the
            // redesign is that no activity needs scrolling to reach.
            .frame(height: height)
            .padding(AppSpacing.tight)
            .background(color.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
            .softShadow()
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(badge.map { "\(title). \($0)" } ?? title)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
        ActivityTile(title: "Learn Letters", emoji: "📖", color: AppColors.primary) {}
        ActivityTile(title: "Play a Game", emoji: "🎯", color: AppColors.success) {}
        ActivityTile(title: "My Rewards", emoji: "🏆", color: AppColors.warning,
                     badge: "12 stars") {}
    }
    .padding()
}
