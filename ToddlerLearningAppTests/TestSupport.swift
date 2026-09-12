//
//  TestSupport.swift
//  ToddlerLearningAppTests
//
//  Fixtures and fakes shared across the test suites.
//

import Foundation
import SwiftData
import Testing

@testable import ToddlerLearningApp

/// A fresh in-memory store with one child in it, so no test can observe
/// another's writes.
///
/// A plain `ModelContext(container)`, not `container.mainContext`: the latter
/// observes app-lifecycle notifications to autosave/reset itself, and the test
/// host process backgrounds almost immediately since it never really presents
/// UI — which was enough to trigger SwiftData's "This model instance was
/// destroyed by calling ModelContext.reset" fatal error mid-test. The
/// production code's own use of `container.mainContext` (AppDependencies) is
/// unaffected; that runs inside a real, foregrounded app.
@MainActor
func makeTestContext(childAge: Int = 4) throws -> (ModelContext, ChildProfile) {
    let container = try ModelContainer(
        for: ChildProfile.self, LetterProgress.self, NumberProgress.self, TraceProgress.self, SessionRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let child = ChildProfile(name: "Test", age: childAge, avatarEmoji: "🐰")
    context.insert(child)
    return (context, child)
}

/// Polls `condition` on the main actor until it holds, for state that settles
/// a task hop or two later — a lock lifting, feedback ending, a line finishing.
@MainActor
func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(3)
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Condition never became true")
            return
        }
        try await Task.sleep(for: .milliseconds(20))
    }
}

/// Returns straight away from everything, so a screen's own timing is all
/// that's left to wait on.
@MainActor
final class SilentSpeech: SpeechServicing {
    func speak(_ text: String) {}
    func speakAndWait(_ sentences: [String]) async {}
    func teachLetter(_ letter: Letter) async {}
    func teachNumber(_ number: NumberItem) async {}
    func stop() {}
}

/// Keeps every `speakAndWait` line "playing" until `finishAll()`, and records
/// what was said — for checking what happens mid-line.
@MainActor
final class HeldSpeech: SpeechServicing {
    private(set) var lines: [[String]] = []
    private var playing: [CheckedContinuation<Void, Never>] = []

    func speak(_ text: String) { lines.append([text]) }

    func speakAndWait(_ sentences: [String]) async {
        lines.append(sentences)
        await withCheckedContinuation { playing.append($0) }
    }

    func teachLetter(_ letter: Letter) async {}
    func teachNumber(_ number: NumberItem) async {}
    func stop() {}

    func finishAll() {
        let finished = playing
        playing = []
        finished.forEach { $0.resume() }
    }
}
