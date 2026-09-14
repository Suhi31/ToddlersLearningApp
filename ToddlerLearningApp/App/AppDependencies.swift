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

    /// Which voice the whole app speaks with. **This is the only thing to
    /// change to A/B the two.**
    ///
    /// - `true`  — the bundled recordings in `Resources/Speech` (see
    ///             docs/VOICE_CLIPS.md), falling back to synthesis for any
    ///             line that has no clip.
    /// - `false` — `AVSpeechSynthesizer` everywhere, ignoring every clip, as
    ///             the app sounded before the recordings existed.
    ///
    /// Rebuild after changing it; nothing else needs touching, because both
    /// paths are `SpeechServicing` and every screen talks to that protocol.
    static let usesRecordedVoice = true

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
        // See `usesRecordedVoice`. The synthesizer is built either way: with
        // recordings on it is the fallback for lines that have no clip, and
        // with them off it is the whole voice.
        let synthesized = SpeechService()
        let base: SpeechServicing = Self.usesRecordedVoice
            ? RecordedSpeechService(fallback: synthesized)
            : synthesized
        self.speechScopes = SpeechScopes(base: base)
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
