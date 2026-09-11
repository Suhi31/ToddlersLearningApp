//
//  CountingObjectDeckTests.swift
//  ToddlerLearningAppTests
//
//  Count & Find only teaches counting if the object on screen says nothing
//  about the answer. These pin the two properties that keep it that way: a
//  round shows a real spread of objects, and none repeats back to back.
//

import Testing

@testable import ToddlerLearningApp

@MainActor
struct CountingObjectDeckTests {

    @Test("Every object is dealt once before any repeats")
    func dealsWholeDeckFirst() {
        let objects = NumberContent.countingObjects
        let deck = CountingObjectDeck(objects: objects)

        let firstPass = (0..<objects.count).map { _ in deck.next() }

        #expect(Set(firstPass) == Set(objects))
    }

    /// Small decks are where a reshuffle is most likely to put the last
    /// object dealt straight back on top.
    @Test("Never the same object twice in a row, even across reshuffles")
    func noBackToBackRepeats() {
        for deckSize in [2, 3, NumberContent.countingObjects.count] {
            let deck = CountingObjectDeck(objects: Array(NumberContent.countingObjects.prefix(deckSize)))

            let dealt = (0..<deckSize * 50).map { _ in deck.next() }

            #expect(zip(dealt, dealt.dropFirst()).allSatisfy { $0 != $1 }, "deck of \(deckSize)")
        }
    }

    @Test("The object pool has no duplicates")
    func poolIsDistinct() {
        let objects = NumberContent.countingObjects

        #expect(Set(objects.map(\.emoji)).count == objects.count)
        #expect(Set(objects.map(\.singular)).count == objects.count)
    }
}
