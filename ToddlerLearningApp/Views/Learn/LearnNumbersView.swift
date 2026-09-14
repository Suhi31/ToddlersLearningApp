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
                    ForEach(0..<number.id, id: \.self) { index in
                        // Each object lights up as the voice reaches it, so a
                        // child can see which thing every spoken number
                        // belongs to. Ones already counted stay full strength;
                        // the rest wait their turn.
                        //
                        // While nothing is being counted `countedSoFar` is nil
                        // and nothing dims.
                        let counted = viewModel.countedSoFar
                        let isCurrent = counted == index + 1
                        let isCounted = (counted ?? 0) > index

                        Text(number.emoji)
                            .font(.system(size: 34))
                            .scaleEffect(isCurrent ? 1.35 : 1.0)
                            .opacity(counted == nil || isCounted ? 1 : 0.35)
                            .animation(.spring(response: 0.28, dampingFraction: 0.55),
                                       value: counted)
                    }
                }
                .frame(maxWidth: 220)
            }
        }
    }
}
