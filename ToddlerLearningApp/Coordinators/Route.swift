//
//  Route.swift
//  ToddlerLearningApp
//
//  Every navigable destination in the app. Keeping these in one enum is what
//  makes the parental gate enforceable: there is exactly one place where a
//  transition into `parentDashboard` can happen.
//

import Foundation

enum Route: Hashable {
    case learnAlphabet
    /// Opens Learn Letters positioned on a specific letter, e.g. from a
    /// rhyme's "Practice letter B" link — a deep-link variant of
    /// `.learnAlphabet`, same shape as `.rhymes` / `.rhymeDetail(String)`.
    case learnAlphabetDetail(String)
    case traceLetters
    case quiz
    case learnNumbers
    /// Deep-link variant of `.learnNumbers`, positioned on a specific number.
    case learnNumbersDetail(Int)
    case numberQuiz
    case wordBuild
    case rhymes
    case rhymeDetail(String)
    case rewards
    case parentGate
    case parentDashboard
    case settings
}

/// Screens presented modally rather than pushed.
enum SheetRoute: Identifiable {
    case switchChild

    var id: String {
        switch self {
        case .switchChild: "switchChild"
        }
    }
}
