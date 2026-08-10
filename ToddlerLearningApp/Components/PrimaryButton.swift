//
//  PrimaryButton.swift
//  ToddlerLearningApp
//

import SwiftUI

struct PrimaryButton: View {

    let title: String
    var color: Color = AppColors.primary
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.button)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppSpacing.minimumTapTarget)
                .background(isEnabled ? color : AppColors.disabledBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
                .raisedShadow(color: isEnabled ? color : .clear)
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(!isEnabled)
    }
}

/// A press should be visible as well as felt — toddlers rely on the squash to
/// confirm the tap registered.
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6),
                       value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "🌟 Let's Play!") {}
        PrimaryButton(title: "Disabled", isEnabled: false) {}
    }
    .padding()
}
