//
//  SessionRecord.swift
//  ToddlerLearningApp
//
//  Backs the daily allowance (spec F5) and the "time played" figure on the
//  parent dashboard. Only foreground time is accumulated.
//

import Foundation
import SwiftData

@Model
final class SessionRecord {

    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var secondsPlayed: Int = 0

    var child: ChildProfile?

    init(startedAt: Date = Date()) {
        self.id = UUID()
        self.startedAt = startedAt
    }
}
