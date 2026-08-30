//
//  SessionTimerService.swift
//  ToddlerLearningApp
//
//  Spec F5. The daily allowance.
//
//  The point of this feature is that the app stops *gracefully*: when the
//  allowance runs out we set `hasReachedLimit`, and it is the screen's job to
//  finish the activity in progress before showing the wind-down. Nothing here
//  cuts a child off mid-question.
//

import Foundation
import OSLog
import SwiftData

/// Save failures are logged rather than surfaced: interrupting a child's
/// session for a write that SwiftData will retry on its next autosave costs
/// more than the failure does.
private let logger = Logger(subsystem: "com.toddlerlearningapp", category: "session")

@MainActor
@Observable
final class SessionTimerService {

    private(set) var secondsPlayedToday: Int = 0
    private(set) var hasReachedLimit: Bool = false
    private(set) var isRunning: Bool = false

    private var currentSession: SessionRecord?
    private var child: ChildProfile?
    private var ticker: Timer?

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Derived

    var limitSeconds: Int {
        guard let child, child.dailyLimitMinutes > 0 else { return 0 }
        return child.dailyLimitMinutes * 60
    }

    var hasLimit: Bool { limitSeconds > 0 }

    var remainingSeconds: Int {
        guard hasLimit else { return .max }
        return max(0, limitSeconds - secondsPlayedToday)
    }

    // MARK: - Lifecycle

    func begin(for child: ChildProfile) {
        guard !isRunning else { return }

        self.child = child
        secondsPlayedToday = Self.secondsPlayed(by: child, on: .now)
        evaluateLimit()
        // Past-limit foreground time still counts (see `evaluateLimit`), so
        // this used to bail out here entirely once the limit was reached —
        // which was the bug: it meant a session record, once past the limit,
        // was never reopened, so "today" on the dashboard froze at exactly
        // the limit no matter how much longer the child kept playing. Now a
        // past-limit foreground bounce opens/resumes a session exactly like
        // any other; the allowance is enforced by the coordinator
        // (`startActivity`/`checkTimeLimitAtSafePoint`), not by starving the
        // clock.

        // A session left open by `suspend()` is resumed rather than replaced.
        // Opening a second record here would both inflate the session count and
        // orphan the first one with no `endedAt`.
        if currentSession == nil || currentSession?.child?.id != child.id {
            closeCurrentSession()

            let session = SessionRecord()
            context.insert(session)
            session.child = child
            currentSession = session
        }

        startTicker()
        isRunning = true
    }

    /// The session is over: stop counting and close the record.
    func pause() {
        stopTicker()
        closeCurrentSession()
        isRunning = false
    }

    /// Transiently interrupted: stop counting, but leave the record open so
    /// returning a moment later continues the same session. See
    /// `RootView.handle(_:)`.
    func suspend() {
        stopTicker()
        isRunning = false
    }

    func end() {
        pause()
        child = nil
    }

    // MARK: - Daily allowance

    /// The daily allowance is the one setting a parent actively chooses, so it
    /// is written through rather than left to SwiftData's autosave — losing it
    /// to a force-quit silently disables the feature.
    func setDailyLimit(_ minutes: Int, for child: ChildProfile) {
        child.dailyLimitMinutes = minutes

        // Lowering the limit below what's already been played should take
        // effect now rather than at the next tick, and raising it should clear
        // a limit that had already been reached.
        if child.id == self.child?.id {
            evaluateLimit()
        }

        save()
    }

    // MARK: - Ticking

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // `.common` so the count keeps running while a scroll view is tracking.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        secondsPlayedToday += 1
        currentSession?.secondsPlayed += 1
        evaluateLimit()
    }

    private func evaluateLimit() {
        guard hasLimit else {
            hasReachedLimit = false
            resumeTickerIfNeeded()
            return
        }
        // The ticker deliberately keeps running past the limit — reaching it
        // no longer stops the clock, only `hasReachedLimit` flips. Stopping
        // the ticker here used to freeze `secondsPlayedToday` (and the
        // dashboard's "today" figure) at exactly the limit no matter how much
        // longer a child kept playing, since actually *ending* the session is
        // the coordinator's job (`startActivity`/`checkTimeLimitAtSafePoint`),
        // not this service's.
        hasReachedLimit = secondsPlayedToday >= limitSeconds
        resumeTickerIfNeeded()
    }

    /// Restarts the ticker if something previously stopped it (`pause()`,
    /// `suspend()`) while a session is meant to be running. In ordinary
    /// operation the ticker no longer stops just because the limit was
    /// reached, so this is mostly a safety net for those other paths — kept
    /// rather than inlined since a caller shouldn't have to know it's a no-op
    /// most of the time.
    ///
    /// Deliberately a no-op unless a session is already running, so the
    /// `evaluateLimit()` inside `begin(for:)` — which runs before `isRunning`
    /// is set — doesn't start the ticker behind `begin`'s back.
    private func resumeTickerIfNeeded() {
        guard isRunning, ticker == nil else { return }
        startTicker()
    }

    private func closeCurrentSession() {
        guard let session = currentSession else { return }
        session.endedAt = .now
        currentSession = nil
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Reporting

    /// Total foreground seconds for a given calendar day.
    static func secondsPlayed(by child: ChildProfile, on date: Date) -> Int {
        let calendar = Calendar.current
        return child.sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.secondsPlayed }
    }

    /// Seconds per day for the last `days` days, oldest first — the dashboard chart.
    static func dailyTotals(for child: ChildProfile, days: Int = 7) -> [(date: Date, seconds: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day, secondsPlayed(by: child, on: day))
        }
    }

    /// Sessions started in the last `days` days — windowed to match
    /// `dailyTotals` rather than `child.sessions.count`, which is every
    /// session ever recorded. Printed on the dashboard between "today" and
    /// "this week", an all-time figure there read unambiguously (but
    /// wrongly) as "sessions this week".
    static func sessionCount(for child: ChildProfile, days: Int = 7) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return child.sessions.count
        }
        return child.sessions.count { $0.startedAt >= windowStart }
    }
}
