//
//  LearnNumbersView.swift
//  ToddlerLearningApp
//
//  Numbers-domain twin of LearnAlphabetView. The illustration shows the
//  number's emoji *repeated* rather than a single picture, since counting the
//  quantity — not just naming the numeral — is the point. That difference is
//  now the only thing this file carries; the rest is BrowseScreen/BrowseStage.
//

import SwiftUI

struct LearnNumbersView: View {

    @State private var viewModel: LearnNumbersViewModel
    private let coordinator: AppCoordinator

    init(viewModel: LearnNumbersViewModel, coordinator: AppCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        BrowseScreen(viewModel: viewModel,
                     coordinator: coordinator,
                     title: "Learn Numbers",
                     itemNoun: "number") { number in
            BrowseStage(item: number,
                        linkedRhymeID: RhymeContent.rhymes(forNumber: number.id).first?.id,
                        onRepeat: { viewModel.repeatSound() },
                        coordinator: coordinator) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6),
                                   count: min(number.id, 5)),
                    spacing: 6
                ) {
                    ForEach(0..<number.id, id: \.self) { _ in
                        Text(number.emoji).font(.system(size: 34))
                    }
                }
                .frame(maxWidth: 220)
            }
        }
    }
}
