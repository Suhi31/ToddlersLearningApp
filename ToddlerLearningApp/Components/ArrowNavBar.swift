//
//  ArrowNavBar.swift
//  ToddlerLearningApp
//
//  The back / centre / forward row shared by Learn Letters, Learn Numbers and
//  Trace Letters. All three had their own verbatim copy of it.
//

import SwiftUI

struct ArrowNavBar<Center: View>: View {

    let canGoBack: Bool
    let canGoForward: Bool

    /// Singular noun for the VoiceOver labels — "letter" gives "Previous
    /// letter" / "Next letter".
    let itemNoun: String

    /// Trace uses a smaller chevron than the Learn screens do.
    var iconSize: CGFloat = 46

    let onBack: () -> Void
    let onForward: () -> Void

    @ViewBuilder let center: () -> Center

    var body: some View {
        HStack {
            arrow("chevron.left.circle.fill",
                  enabled: canGoBack,
                  label: "Previous \(itemNoun)",
                  action: onBack)

            Spacer()

            center()

            Spacer()

            arrow("chevron.right.circle.fill",
                  enabled: canGoForward,
                  label: "Next \(itemNoun)",
                  action: onForward)
        }
    }

    private func arrow(_ systemName: String,
                       enabled: Bool,
                       label: String,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize))
                .foregroundStyle(enabled ? AppColors.primary : AppColors.disabledIcon)
                .frame(width: AppSpacing.minimumTapTarget, height: AppSpacing.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
