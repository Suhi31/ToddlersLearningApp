//
//  AppDependencies.swift
//  ToddlerLearningApp
//
//  A single composition root. Services are constructed once, here, and handed
//  to ViewModels by the coordinator — no ViewModel reaches for a singleton.
//

import Foundation
import SwiftData

@MainActor
final class AppDependencies {

    let modelContext: ModelContext
    let speechService: SpeechServicing
    let progressService: ProgressService
    let rewardService: RewardService
    let sessionTimer: SessionTimerService
    let haptics: HapticsService
    let rhymeAudioService: RhymeAudioPlaying

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Wrapped so any bundled voice clips (see RecordedSpeechService's
        // header comment for the naming convention) play automatically —
        // with none bundled yet, this behaves identically to `SpeechService()`.
        self.speechService = RecordedSpeechService(fallback: SpeechService())
        self.progressService = ProgressService(context: modelContext)
        self.rewardService = RewardService(context: modelContext)
        self.sessionTimer = SessionTimerService(context: modelContext)
        self.haptics = HapticsService()
        self.rhymeAudioService = RhymeAudioService()
    }

    /// In-memory stack for previews and tests.
    static func preview() -> AppDependencies {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ChildProfile.self, LetterProgress.self, NumberProgress.self, SessionRecord.self,
            configurations: configuration
        )
        return AppDependencies(modelContext: container.mainContext)
    }
}
