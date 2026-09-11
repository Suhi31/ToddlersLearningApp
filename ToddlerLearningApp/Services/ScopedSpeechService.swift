//
//  ScopedSpeechService.swift
//  ToddlerLearningApp
//
//  Every screen talks through the one real speech service, but each gets its
//  own handle onto it from `SpeechScopes`. A handle forwards everything as-is,
//  except that its `stop()` only takes effect if that handle was the last one
//  to speak — a screen can silence its own speech, never another screen's.
//
//  This is down to when SwiftUI fires lifecycle callbacks on a NavigationStack
//  push: the new screen's `onAppear` runs right away, but the screen beneath
//  only gets `onDisappear` once the push animation has finished, ~0.6s later.
//  Every screen calls `stop()` from `onDisappear` so it doesn't talk over what
//  comes next, and with one shared service that late `stop()` from Home landed
//  on the new screen's opening line instead — tapping Trace Letters said
//  "Trace the…" and went quiet.
//

import Foundation

@MainActor
final class SpeechScopes {

    private let base: SpeechServicing

    /// The handle that spoke most recently. Weak, so a screen that has since
    /// been torn down holds no claim.
    fileprivate weak var owner: ScopedSpeechService?

    init(base: SpeechServicing) {
        self.base = base
    }

    /// One per screen — two screens sharing a handle could stop each other's
    /// speech again.
    func makeScope() -> SpeechServicing {
        ScopedSpeechService(base: base, scopes: self)
    }
}

@MainActor
private final class ScopedSpeechService: SpeechServicing {

    private let base: SpeechServicing
    private let scopes: SpeechScopes

    init(base: SpeechServicing, scopes: SpeechScopes) {
        self.base = base
        self.scopes = scopes
    }

    func speak(_ text: String) {
        claim()
        base.speak(text)
    }

    func speakAndWait(_ sentences: [String]) async {
        claim()
        await base.speakAndWait(sentences)
    }

    func teachLetter(_ letter: Letter) async {
        claim()
        await base.teachLetter(letter)
    }

    func teachNumber(_ number: NumberItem) async {
        claim()
        await base.teachNumber(number)
    }

    /// A no-op once another screen has spoken since — whatever is playing
    /// now belongs to that screen, not this one.
    func stop() {
        guard scopes.owner === self else { return }
        base.stop()
    }

    private func claim() {
        scopes.owner = self
    }
}
