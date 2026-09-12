//
//  PlaybackTrackerTests.swift
//  ToddlerLearningAppTests
//
//  The "is it still playing?" check behind every tap-to-hear-again control.
//

import Testing

@testable import ToddlerLearningApp

@MainActor
struct PlaybackTrackerTests {

    @Test("Playing from start until the playback returns")
    func tracksOnePlayback() async throws {
        let tracker = PlaybackTracker()
        let speech = HeldSpeech()

        tracker.start { await speech.speakAndWait(["one"]) }
        #expect(tracker.isPlaying)
        try await waitUntil { speech.lines.count == 1 }
        #expect(tracker.isPlaying)

        speech.finishAll()
        try await waitUntil { !tracker.isPlaying }
    }

    /// The case the generation counter exists for: the older playback, cut off
    /// by a newer one, returning while the newer one is still going.
    @Test("An older playback finishing late doesn't mark a newer one finished")
    func stalePlaybackDoesNotClearNewer() async throws {
        let tracker = PlaybackTracker()
        let older = HeldSpeech()
        let newer = HeldSpeech()

        tracker.start { await older.speakAndWait(["older"]) }
        tracker.start { await newer.speakAndWait(["newer"]) }
        try await waitUntil { older.lines.count == 1 && newer.lines.count == 1 }

        older.finishAll()
        try await Task.sleep(for: .milliseconds(50))
        #expect(tracker.isPlaying, "Only the newer playback's end may clear it")

        newer.finishAll()
        try await waitUntil { !tracker.isPlaying }
    }
}
