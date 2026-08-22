//
//  StorageWarningBanner.swift
//  ToddlerLearningApp
//
//  Shown only when the on-disk store failed to open and the app fell back to
//  an in-memory container — see `ToddlerLearningAppApp.makeContainer()`.
//  Worded for the parent, not the child: it is the parent who needs to know
//  that today's stars won't be there tomorrow.
//

import SwiftUI

struct StorageWarningBanner: View {

    var body: some View {
        Label {
            Text("Progress can't be saved right now. Reinstalling the app usually fixes this.")
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.title)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.warning)
        }
        .padding(AppSpacing.tight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.tileCornerRadius))
        .softShadow()
        .padding(.horizontal, AppSpacing.tight)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    StorageWarningBanner()
}
