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

    private let rhymeAudioService: RhymeAudioPlaying
    private let haptics: HapticsService

    init(rhymeAudioService: RhymeAudioPlaying, haptics: HapticsService) {
        self.rhymeAudioService = rhymeAudioService
        self.haptics = haptics
    }

    /// The rhyme the child is on, playing or paused — the detail screen pauses
    /// rather than stopping when it leaves, so coming back here the tile they
    /// were listening to is still marked.
    func isCurrent(_ rhyme: Rhyme) -> Bool {
        rhymeAudioService.currentRhymeID == rhyme.id
    }

    func isPlaying(_ rhyme: Rhyme) -> Bool {
        isCurrent(rhyme) && rhymeAudioService.isPlaying
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
