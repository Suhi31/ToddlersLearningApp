//
//  RhymeAudioServiceTests.swift
//  ToddlerLearningAppTests
//
//  The read-aloud fallback for rhymes with no bundled recording.
//

import Foundation
import Testing

@testable import ToddlerLearningApp

@MainActor
struct RhymeAudioServiceTests {

    /// iOS reports a *stopped* line as finished too, so a quick play → pause →
    /// play used to deliver a stale finish that skipped the new first line.
    /// Checked straight after the call, before the synthesizer's own callbacks
    /// can hop back to the main actor, so the result is deterministic.
    @Test("A finish reported for a line that isn't playing doesn't move the rhyme on")
    func staleFinishIsIgnored() {
        // A made-up audio file name, so this always takes the read-aloud path
        // regardless of which rhymes currently ship a bundled recording.
        let rhyme = Rhyme(
            id: "test-rhyme",
            title: "Test Rhyme",
            lines: ["Line one.", "Line two."],
            audioFileName: "no-such-clip.m4a",
            emoji: "🎵",
            colorIndex: 0,
            linkage: .general
        )
        let service = RhymeAudioService()
        service.play(rhyme)
        defer { service.stop() }
        #expect(service.isPlaying)

        service.handleFinish(utteranceID: ObjectIdentifier(NSObject()))

        #expect(service.progress == 0, "A stale finish must not advance to the next line")
        #expect(service.isPlaying)
    }
}
