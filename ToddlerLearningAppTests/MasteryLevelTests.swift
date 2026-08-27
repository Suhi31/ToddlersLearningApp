//
//  MasteryLevelTests.swift
//  ToddlerLearningAppTests
//
//  `MasteryLevel` is the whole adaptive model in one enum: the stage ladder and
//  the sampling weight that decides how often a stage recurs. Both are trivial
//  to change by accident and impossible to see change from the UI.
//

import Testing

@testable import ToddlerLearningApp

struct MasteryLevelTests {

    @Test("Promotion walks up one stage and stops at mastered",
          arguments: [(MasteryLevel.new, MasteryLevel.learning),
                      (.learning, .mastered),
                      (.mastered, .mastered)])
    func promotion(from level: MasteryLevel, to expected: MasteryLevel) {
        #expect(level.promoted == expected)
    }

    @Test("Demotion walks down one stage and stops at new",
          arguments: [(MasteryLevel.mastered, MasteryLevel.learning),
                      (.learning, .new),
                      (.new, .new)])
    func demotion(from level: MasteryLevel, to expected: MasteryLevel) {
        #expect(level.demoted == expected)
    }

    @Test("Unmastered stages are sampled four times as often as mastered ones")
    func selectionWeights() {
        #expect(MasteryLevel.new.selectionWeight == 4)
        #expect(MasteryLevel.learning.selectionWeight == 4)
        #expect(MasteryLevel.mastered.selectionWeight == 1)
        #expect(MasteryLevel.new.selectionWeight == 4 * MasteryLevel.mastered.selectionWeight,
                "Spec F2 fixes this ratio at roughly 4:1")
    }

    @Test("Every stage survives a raw-value round trip")
    func rawValueRoundTrip() {
        for level in MasteryLevel.allCases {
            #expect(MasteryLevel(rawValue: level.rawValue) == level)
        }
    }

    @Test("An unrecognised stored raw value is treated as new, not a crash")
    func unknownRawValueIsNil() {
        // LetterProgress.mastery relies on this returning nil to fall back to
        // `.new` after a schema change writes a stage this build doesn't know.
        #expect(MasteryLevel(rawValue: 99) == nil)
    }
}
