//
//  LearnAlphabetView.swift
//  ToddlerLearningApp
//
//  Everything except the illustration lives in BrowseScreen/BrowseStage,
//  shared with Learn Numbers.
//

import SwiftUI

struct LearnAlphabetView: View {

    @State private var viewModel: LearnAlphabetViewModel
    private let coordinator: AppCoordinator

    init(viewModel: LearnAlphabetViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        BrowseScreen(viewModel: viewModel,
                     coordinator: coordinator,
                     title: "Learn Letters",
                     itemNoun: "letter") { letter in
            // No "Hear a rhyme" link on this screen — `nil` hides it.
            BrowseStage(item: letter,
                        linkedRhymeID: nil,
                        onRepeat: { viewModel.repeatSound() },
                        coordinator: coordinator) {
                HStack(spacing: AppSpacing.section) {
                    ForEach(letter.emojis, id: \.self) { emoji in
                        Text(emoji).font(.system(size: 54))
                    }
                }
            }
        }
    }
}
