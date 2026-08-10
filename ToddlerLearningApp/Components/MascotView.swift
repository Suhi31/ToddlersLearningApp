//
//  MascotView.swift
//  ToddlerLearningApp
//

import SwiftUI

/// The friendly face. Idles with a slow bob so the screen never looks frozen to
/// a child deciding whether the app is "on".
struct MascotView: View {

    var emoji: String = "🐻"
    var size: CGFloat = 110

    @State private var isBobbing = false

    var body: some View {
        Text(emoji)
            .font(.system(size: size))
            .offset(y: isBobbing ? -10 : 10)
            .animation(
                .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                value: isBobbing
            )
            .onAppear { isBobbing = true }
            .accessibilityHidden(true)
    }
}

#Preview {
    MascotView()
}
