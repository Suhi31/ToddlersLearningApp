//
//  RhymesViewModel.swift
//  ToddlerLearningApp
//
//  The browse screen: a grid of every rhyme. No quiz/mastery grading exists
//  for rhymes, so — like WordBuildViewModel — this is session-only, with no
//  persisted progress domain of its own. Tapping a card pushes
//  .rhymeDetail(id); the player itself lives in RhymeDetailViewModel.
//

import Foundation

@MainActor
@Observable
final class RhymesViewModel {

    let rhymes: [Rhyme] = RhymeContent.rhymes

    private let haptics: HapticsService

    init(haptics: HapticsService) {
        self.haptics = haptics
    }

    func onAppear() {
        haptics.prepare()
    }

    func selected(_ rhyme: Rhyme) {
        haptics.tap()
    }

    /// A short "goes with letter B" / "goes with number 5" caption for the
    /// card, nil for general sing-alongs with no tie-in.
    func linkageCaption(for rhyme: Rhyme) -> String? {
        switch rhyme.linkage {
        case .letter(let id): "🔤 Goes with letter \(id)"
        case .number(let value): "🔢 Goes with number \(value)"
        case .general: nil
        }
    }
}
