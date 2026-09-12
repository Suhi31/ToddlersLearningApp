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
    func staleFinishIsIgnored() throws {
        // Any rhyme without a bundled recording takes the read-aloud path.
        let rhyme = try #require(RhymeContent.rhyme(id: "hickory-dickory-dock"))
        let service = RhymeAudioService()
        service.play(rhyme)
        defer { service.stop() }
        #expect(service.isPlaying)

        service.handleFinish(utteranceID: ObjectIdentifier(NSObject()))

        #expect(service.progress == 0, "A stale finish must not advance to the next line")
        #expect(service.isPlaying)
    }
}
