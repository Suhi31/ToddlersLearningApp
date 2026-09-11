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
    let progressService: ProgressService
    let childProfileService: ChildProfileService
    let rewardService: RewardService
    let sessionTimer: SessionTimerService
    let haptics: HapticsService
    let rhymeAudioService: RhymeAudioPlaying

    /// Not exposed directly: each screen takes its own handle from
    /// `makeSpeechService()`. See `SpeechScopes`.
    private let speechScopes: SpeechScopes

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Wrapped so any bundled voice clips (see RecordedSpeechService's
        // header comment for the naming convention) play automatically —
        // with none bundled yet, this behaves identically to `SpeechService()`.
        self.speechScopes = SpeechScopes(base: RecordedSpeechService(fallback: SpeechService()))
        self.progressService = ProgressService(context: modelContext)
        self.childProfileService = ChildProfileService(context: modelContext)
        self.rewardService = RewardService(context: modelContext)
        self.sessionTimer = SessionTimerService(context: modelContext)
        self.haptics = HapticsService()
        self.rhymeAudioService = RhymeAudioService()
    }

    /// A new handle onto the one shared speech service, for a single screen's
    /// view model. Never hand one handle to two screens — see `SpeechScopes`.
    func makeSpeechService() -> SpeechServicing {
        speechScopes.makeScope()
    }

    /// In-memory stack for previews and tests.
    static func preview() -> AppDependencies {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ChildProfile.self, LetterProgress.self, NumberProgress.self, TraceProgress.self, SessionRecord.self,
            configurations: configuration
        )
        return AppDependencies(modelContext: container.mainContext)
    }
}
