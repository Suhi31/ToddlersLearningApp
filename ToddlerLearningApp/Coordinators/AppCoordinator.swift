//
//  AppCoordinator.swift
//  ToddlerLearningApp
//
//  Owns the navigation stack and the active child. It also builds destination
//  views, which is what keeps `Route` -> screen mapping in a single file
//  instead of scattered across `NavigationLink`s.
//

import SwiftUI

@MainActor
@Observable
final class AppCoordinator: Coordinator {

    var path: [Route] = []
    var sheet: SheetRoute?

    /// Drives the wind-down screen. Set only at a safe stopping point — see
    /// `checkTimeLimitAtSafePoint()`.
    var showTimeUp = false

    /// Set when the child dismisses the wind-down, cleared once the allowance
    /// is no longer exhausted. See `checkTimeLimitAtSafePoint()`.
    private var hasAcknowledgedTimeUp = false

    /// `nil` until onboarding completes or a saved profile is loaded.
    private(set) var activeChild: ChildProfile?

    var isOnboarded: Bool { activeChild != nil }

    let dependencies: AppDependencies

    var sessionTimer: SessionTimerService { dependencies.sessionTimer }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    // MARK: - Session

    func start(with child: ChildProfile) {
        activeChild = child
        hasAcknowledgedTimeUp = false
        Self.persistLastActiveChildID(child.id)
        dependencies.rewardService.registerPlay(for: child)
        dependencies.sessionTimer.begin(for: child)
        popToRoot()
    }

    func switchTo(_ child: ChildProfile) {
        dependencies.sessionTimer.end()
        start(with: child)
        sheet = nil
    }

    /// Called when the last remaining child profile is deleted — there's
    /// nothing left to show, so this routes back to onboarding (spec F1) via
    /// `isOnboarded` turning false.
    func clearActiveChild() {
        dependencies.sessionTimer.end()
        activeChild = nil
        Self.clearLastActiveChildID()
        sheet = nil
        popToRoot()
    }

    /// Backgrounded — the play session is genuinely over.
    func endSession() {
        dependencies.sessionTimer.pause()
    }

    /// Transiently interrupted (app-switcher peek, Control Centre, a banner).
    /// Stops counting time but leaves the session record open, so a quick
    /// return resumes it instead of opening a second one.
    func suspendSession() {
        dependencies.sessionTimer.suspend()
    }

    func resumeSession() {
        guard let activeChild else { return }
        // Re-arm the wind-down: without this, a child who dismissed "All
        // done" earlier today, backgrounded the app mid-activity while still
        // over the limit, and returned would sail past the next safe
        // stopping point — `hasAcknowledgedTimeUp` was still `true` from
        // before, so `checkTimeLimitAtSafePoint()` would stay silent even
        // though the allowance is (still) exhausted. Resetting it here means
        // every foreground return gets a fresh chance to show the wind-down.
        hasAcknowledgedTimeUp = false
        dependencies.sessionTimer.begin(for: activeChild)
    }

    // MARK: - Daily allowance

    /// Screens call this when they reach a natural break — between quiz
    /// questions, on returning to Home — never mid-activity. That is the whole
    /// point of spec F5: the allowance ends the session, it doesn't interrupt it.
    func checkTimeLimitAtSafePoint() {
        guard dependencies.sessionTimer.hasReachedLimit else {
            // The allowance is no longer exhausted — a new day, or a parent
            // raising the limit. Re-arm the wind-down for next time.
            hasAcknowledgedTimeUp = false
            return
        }
        guard !hasAcknowledgedTimeUp else { return }
        showTimeUp = true
    }

    func dismissTimeUp() {
        showTimeUp = false
        // `popToRoot` makes Home re-appear, and Home checks the allowance on
        // appear — without this flag, dismissing from any pushed screen
        // re-presented the very screen just dismissed, so "All done" read as a
        // broken button.
        hasAcknowledgedTimeUp = true
        popToRoot()
    }

    /// The only way any Home activity tile starts an activity — never
    /// `push(_:)` directly. Home is always a safe stopping point (spec F5),
    /// so this is where the allowance is actually enforced: without it, a
    /// child who dismissed "All done" could immediately tap straight back
    /// into a fresh activity, since nothing else stood between Home and
    /// `push(_:)`. Checked directly against `hasReachedLimit`, not
    /// `hasAcknowledgedTimeUp` — that flag only suppresses the *automatic*
    /// re-check in `checkTimeLimitAtSafePoint()` right after a dismissal, and
    /// must not also suppress a new, explicit attempt to start something.
    func startActivity(_ route: Route) {
        guard !dependencies.sessionTimer.hasReachedLimit else {
            showTimeUp = true
            return
        }
        push(route)
    }

    // MARK: - Gated navigation

    /// The only way into the parent area. Routing it through here means no
    /// screen can accidentally link straight past the gate (spec F3).
    func openParentArea() {
        push(.parentGate)
    }

    /// Called by the gate once solved. Replaces the gate in the stack so that
    /// "back" from the dashboard returns to the child's screen, not the puzzle.
    func parentGatePassed() {
        if path.last == .parentGate {
            path.removeLast()
        }
        push(.parentDashboard)
    }

    // MARK: - Destinations

    @ViewBuilder
    func destination(for route: Route) -> some View {
        // Every route below but the three parent-area/settings ones needs an
        // active child, and in ordinary use one always exists by the time a
        // route is reachable — onboarding gates everything. This guard is for
        // the one abnormal case: the active child being deleted (or a switch
        // in progress) while a route for it is still mid-transition on the
        // navigation stack. That used to be a `preconditionFailure` crash;
        // `.rhymeDetail` below already shows the better alternative for a
        // route whose target has gone missing.
        if let activeChild {
            switch route {
            case .learnAlphabet:
                LearnAlphabetView(
                    viewModel: LearnAlphabetViewModel(
                        child: activeChild,
                        speechService: dependencies.makeSpeechService(),
                        progressService: dependencies.progressService,
                        haptics: dependencies.haptics
                    ),
                    coordinator: self
                )

            case .learnAlphabetDetail(let letterID):
                LearnAlphabetView(
                    viewModel: LearnAlphabetViewModel(
                        child: activeChild,
                        startingItem: AlphabetContent.letter(id: letterID),
                        speechService: dependencies.makeSpeechService(),
                        progressService: dependencies.progressService,
                        haptics: dependencies.haptics
                    ),
                    coordinator: self
                )

            case .traceLetters:
                TraceLetterView(
                    viewModel: TraceLetterViewModel(
                        child: activeChild,
                        speechService: dependencies.makeSpeechService(),
                        rewardService: dependencies.rewardService,
                        progressService: dependencies.progressService,
                        haptics: dependencies.haptics
                    ),
                    coordinator: self
                )

            case .quiz:
                QuizView(
                    viewModel: QuizViewModel(
                        child: activeChild,
                        speechService: dependencies.makeSpeechService(),
                        progressService: dependencies.progressService,
                        rewardService: dependencies.rewardService,
                        haptics: dependencies.haptics
                    ),
                    coordinator: self
                )

            case .learnNumbers:
                LearnNumbersView(
                    viewModel: LearnNumbersViewModel(
                        child: activeChild,
                        speechService: dependencies.makeSpeechService(),
                        progressService: dependencies.progressService,
                        haptics: dependencies.haptics
                    ),
                    coordinator: self
                )

            case .learnNumbersDetail(let numberID):
                LearnNumbersView(
                    viewModel: LearnNumbersViewModel(
                        child: activeChild,
                        startingItem: NumberContent.number(id: numberID),
                        speechService: dependencies.makeSpeechService(),
                        progressService: dependencies.progressService,
                        haptics: dependencies.haptics
                    ),
                    coordinator: self
                )

            case .numberQuiz:
                NumberQuizView(
                    viewModel: NumberQuizViewModel(
                        child: activeChild,
                        speechService: dependencies.makeSpeechService(),
                        progressService: dependencies.progressService,
                        rewardService: dependencies.rewardService,
                        haptics: dependencies.haptics
                    ),
                    coordinator: self
                )

            case .wordBuild:
                WordBuildView(
                    viewModel: WordBuildViewModel(
                        child: activeChild,
                        speechService: dependencies.makeSpeechService(),
                        rewardService: dependencies.rewardService,
                        haptics: dependencies.haptics
                    ),
                    coordinator: self
                )

            case .rhymes:
                RhymesView(
                    viewModel: RhymesViewModel(haptics: dependencies.haptics),
                    coordinator: self
                )

            case .rhymeDetail(let id):
                if let rhyme = RhymeContent.rhyme(id: id) {
                    RhymeDetailView(
                        viewModel: RhymeDetailViewModel(
                            rhyme: rhyme,
                            speechService: dependencies.makeSpeechService(),
                            rhymeAudioService: dependencies.rhymeAudioService,
                            haptics: dependencies.haptics
                        ),
                        coordinator: self
                    )
                } else {
                    // Every other case in this switch is total. Without this one a
                    // rhyme id that no longer resolves pushes a blank screen the
                    // child can only back out of.
                    ContentUnavailableView("That rhyme isn't here",
                                           systemImage: "music.note")
                }

            case .rewards:
                RewardsView(
                    viewModel: RewardsViewModel(
                        child: activeChild,
                        rewardService: dependencies.rewardService
                    )
                )

            case .parentGate:
                ParentGateView(coordinator: self)

            case .parentDashboard:
                ParentDashboardView(
                    viewModel: ParentDashboardViewModel(
                        child: activeChild,
                        sessionTimer: dependencies.sessionTimer
                    ),
                    coordinator: self
                )

            case .settings:
                SettingsView(coordinator: self)
            }
        } else {
            ContentUnavailableView("Nothing to show", systemImage: "person.crop.circle.badge.exclamationmark")
        }
    }

    // MARK: - Resuming across relaunch (spec F1)

    private static let lastActiveChildIDKey = "lastActiveChildID"

    private static func persistLastActiveChildID(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: lastActiveChildIDKey)
    }

    private static func clearLastActiveChildID() {
        UserDefaults.standard.removeObject(forKey: lastActiveChildIDKey)
    }

    /// The child that was active when the app was last backgrounded or
    /// killed, so a household with siblings resumes the one they were
    /// actually using rather than always reopening the oldest profile.
    static func lastActiveChildID() -> UUID? {
        UserDefaults.standard.string(forKey: lastActiveChildIDKey).flatMap(UUID.init)
    }
}
