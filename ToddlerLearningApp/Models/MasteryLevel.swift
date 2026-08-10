//
//  MasteryLevel.swift
//  ToddlerLearningApp
//

import Foundation

/// Three-stage mastery model backing the adaptive quiz (spec F2).
enum MasteryLevel: Int, Codable, CaseIterable, Sendable {

    case new = 0
    case learning = 1
    case mastered = 2

    var title: String {
        switch self {
        case .new: "Not started"
        case .learning: "Learning"
        case .mastered: "Mastered"
        }
    }

    /// Relative frequency with which a letter at this level is offered by the
    /// quiz. Unseen and shaky letters come up roughly four times as often as
    /// mastered ones, which keeps practice on the edge of ability.
    var selectionWeight: Int {
        switch self {
        case .new: 4
        case .learning: 4
        case .mastered: 1
        }
    }

    var promoted: MasteryLevel {
        MasteryLevel(rawValue: min(rawValue + 1, MasteryLevel.mastered.rawValue)) ?? self
    }

    var demoted: MasteryLevel {
        MasteryLevel(rawValue: max(rawValue - 1, MasteryLevel.new.rawValue)) ?? self
    }
}
