//
//  SpokenPhrases.swift
//  ToddlerLearningApp
//
//  Wording shared by more than one activity's spoken lines, so a rule about
//  how something is said lives in one place rather than in every game.
//

import Foundation

enum Spoken {

    /// A letter's name for use in a sentence: always "the letter A", never a
    /// bare "A". The voice reads a lone A as the word "a" ("uh"), and E blurs
    /// the same way; "the letter A" comes out clearly every time.
    static func letter(_ id: String) -> String {
        "the letter \(id)"
    }
}

/// Openers for correct-answer lines, shared by the quizzes and Build the Word.
/// Several rather than one fixed "Great job" — the exact same reply every time
/// is what reads as robotic.
enum Praise {

    static func opener(childName: String) -> String {
        let exclamations = [
            "Yes", "Great job", "Well done", "You got it", "Brilliant", "Woohoo",
            "Fantastic", "Amazing", "Super job", "Way to go", "You nailed it", "High five"
        ]
        let exclamation = exclamations.randomElement() ?? "Yes"
        // The name on every single line gets repetitive fast; about half is plenty.
        guard !childName.isEmpty, Bool.random() else { return exclamation + "!" }
        return "\(exclamation), \(childName)!"
    }

    /// For a correct retry after a miss: warm, but not the full celebration.
    static func retryOpener() -> String {
        ["That's it!", "There it is!", "You found it!"].randomElement() ?? "That's it!"
    }
}
