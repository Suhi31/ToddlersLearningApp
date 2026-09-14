//
//  CountingTimingTests.swift
//  ToddlerLearningAppTests
//
//  Learn Numbers plays one recorded clip per count, and lights each object up
//  from that clip's timing file. A timing file that doesn't reach the bundle
//  fails silently — the count plays and nothing lights — so check the bundle.
//

import AVFoundation
import Testing

@testable import ToddlerLearningApp

@MainActor
struct CountingTimingTests {

    @Test("Every recorded count has one onset per number, in order, inside its clip")
    func everyCountingClipIsTimed() throws {
        for number in NumberContent.numbers {
            let clip = try #require(Bundle.main.url(forResource: "number-\(number.id)-counting",
                                                    withExtension: "m4a"),
                                    "no counting clip for \(number.id)")
            let onsets = RecordedSpeechService.countingOnsets(for: number, in: .main)

            #expect(onsets.count == number.id, "no usable timing for \(number.id)")
            #expect(onsets.first == 0, "\(number.id): \"one\" should light up as playback starts")
            #expect(zip(onsets, onsets.dropFirst()).allSatisfy { $0 < $1 },
                    "\(number.id): onsets out of order \(onsets)")

            let duration = try AVAudioPlayer(contentsOf: clip).duration
            #expect((onsets.last ?? 0) < duration,
                    "\(number.id): last onset \(onsets.last ?? 0)s is past the clip's end (\(duration)s)")
        }
    }
}
