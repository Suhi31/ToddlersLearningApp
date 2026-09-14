//
//  SpokenPhrases.swift
//  ToddlerLearningApp
//
//  Wording shared by more than one activity's spoken lines, so a rule about
//  how something is said lives in one place rather than in every game.
//

import Foundation

enum Spoken {

    /// A letter's name for use in a sentence — just "A", the way a person
    /// reads one aloud.
    ///
    /// This used to be "the letter A", added when bare letters were being
    /// synthesized and a lone A came out as the word "a" ("uh"), with E
    /// blurring the same way. Recorded lines don't have that problem: the clip
    /// says the letter name outright (see docs/VOICE_CLIPS.md, where each
    /// letter's pronunciation is pinned). And the scaffolding read badly once
    /// recorded — a clip of "the letter B" says "the letter Bee", which hears
    /// as the insect.
    static func letter(_ id: String) -> String {
        id
    }
}

/// Openers for correct-answer lines, shared by the quizzes, Build the Word and
/// tracing. Several rather than one fixed "Great job" — the exact same reply
/// every time is what reads as robotic.
///
/// **No child's name.** Praise used to be "Woohoo, Mih!", which could never be
/// a recording, so that line was synthesized while the sentence after it played
/// as a clip — two different voices inside one breath. The name is gone rather
/// than the recordings, so every line a child hears in a sequence is the same
/// voice.
enum Praise {

    /// Two openers are deliberately absent. "High five" came out as "high
    /// fives" — the voice's own trouble with that word, not a wording choice —
    /// and "Woohoo" simply didn't sound natural when spoken. Both were removed
    /// after listening; keep this list in step with `PRAISE` in
    /// tools/gen_phase_b.py, since clips are indexed by position.
    static let exclamations = [
        "Yes", "Great job", "Well done", "You got it", "Brilliant",
        "Fantastic", "Amazing", "Super job", "Way to go", "You nailed it"
    ]

    static let retryExclamations = ["That's it!", "There it is!", "You found it!"]

    /// `childName` is accepted but unused — see the type's note. Kept in the
    /// signature so the call sites still read as "praise for this child", and
    /// so restoring a name later is one change here rather than five.
    static func opener(childName: String = "") -> SpokenLine {
        let index = Int.random(in: 0..<exclamations.count)
        return SpokenLine(clip: Clip.praise(index), text: exclamations[index] + "!")
    }

    /// For a correct retry after a miss: warm, but not the full celebration.
    static func retryOpener() -> SpokenLine {
        let index = Int.random(in: 0..<retryExclamations.count)
        return SpokenLine(clip: Clip.retryPraise(index), text: retryExclamations[index])
    }
}

/// The mascot's greeting on Home. Name-free like `Praise`, so it plays as a
/// recording rather than dropping the one screen a child taps most back into
/// synthesized speech.
enum Greeting {

    static let lines = [
        "Hi! Ready to play?",
        "Hello! Let's have some fun!",
        "Hey! Ready for an adventure?",
        "Hiya! What should we learn today?",
        "Boo! Just kidding — let's play!"
    ]

    static func random() -> SpokenLine {
        let index = Int.random(in: 0..<lines.count)
        return SpokenLine(clip: Clip.greeting(index), text: lines[index])
    }
}
