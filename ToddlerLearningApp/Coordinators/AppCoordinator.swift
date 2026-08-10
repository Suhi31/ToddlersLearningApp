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

    func endSession() {
        dependencies.sessionTimer.pause()
    }

    func resumeSession() {
        guard let activeChild else { return }
        dependencies.sessionTimer.begin(for: activeChild)
    }

    // MARK: - Daily allowance

    /// Screens call this when they reach a natural break — between quiz
    /// questions, on returning to Home — never mid-activity. That is the whole
    /// point of spec F5: the allowance ends the session, it doesn't interrupt it.
    func checkTimeLimitAtSafePoint() {
        guard dependencies.sessionTimer.hasReachedLimit else { return }
        showTimeUp = true
    }

    func dismissTimeUp() {
        showTimeUp = false
        popToRoot()
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
        switch route {
        case .learnAlphabet:
            LearnAlphabetView(
                viewModel: LearnAlphabetViewModel(
                    child: requireChild(),
                    speechService: dependencies.speechService,
                    progressService: dependencies.progressService,
                    haptics: dependencies.haptics
                ),
                coordinator: self
            )

        case .learnAlphabetDetail(let letterID):
            LearnAlphabetView(
                viewModel: LearnAlphabetViewModel(
                    child: requireChild(),
                    startingItem: AlphabetContent.letter(id: letterID),
                    speechService: dependencies.speechService,
                    progressService: dependencies.progressService,
                    haptics: dependencies.haptics
                ),
                coordinator: self
            )

        case .traceLetters:
            TraceLetterView(
                viewModel: TraceLetterViewModel(
                    child: requireChild(),
                    speechService: dependencies.speechService,
                    rewardService: dependencies.rewardService,
                    haptics: dependencies.haptics
                ),
                coordinator: self
            )

        case .quiz:
            QuizView(
                viewModel: QuizViewModel(
                    child: requireChild(),
                    speechService: dependencies.speechService,
                    progressService: dependencies.progressService,
                    rewardService: dependencies.rewardService,
                    haptics: dependencies.haptics
                ),
                coordinator: self
            )

        case .learnNumbers:
            LearnNumbersView(
                viewModel: LearnNumbersViewModel(
                    child: requireChild(),
                    speechService: dependencies.speechService,
                    progressService: dependencies.progressService,
                    haptics: dependencies.haptics
                ),
                coordinator: self
            )

        case .learnNumbersDetail(let numberID):
            LearnNumbersView(
                viewModel: LearnNumbersViewModel(
                    child: requireChild(),
                    startingItem: NumberContent.number(id: numberID),
                    speechService: dependencies.speechService,
                    progressService: dependencies.progressService,
                    haptics: dependencies.haptics
                ),
                coordinator: self
            )

        case .numberQuiz:
            NumberQuizView(
                viewModel: NumberQuizViewModel(
                    child: requireChild(),
                    speechService: dependencies.speechService,
                    progressService: dependencies.progressService,
                    rewardService: dependencies.rewardService,
                    haptics: dependencies.haptics
                ),
                coordinator: self
            )

        case .wordBuild:
            WordBuildView(
                viewModel: WordBuildViewModel(
                    child: requireChild(),
                    speechService: dependencies.speechService,
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
                        speechService: dependencies.speechService,
                        rhymeAudioService: dependencies.rhymeAudioService,
                        haptics: dependencies.haptics
                    ),
                    coordinator: self
                )
            }

        case .rewards:
            RewardsView(
                viewModel: RewardsViewModel(
                    child: requireChild(),
                    rewardService: dependencies.rewardService
                )
            )

        case .parentGate:
            ParentGateView(coordinator: self)

        case .parentDashboard:
            ParentDashboardView(
                viewModel: ParentDashboardViewModel(
                    child: requireChild(),
                    sessionTimer: dependencies.sessionTimer
                ),
                coordinator: self
            )

        case .settings:
            SettingsView(coordinator: self)
        }
    }

    /// Every destination requires an active child, and every destination is only
    /// reachable after onboarding — so this is a programmer error, not a runtime
    /// condition worth threading optionals through the whole view layer for.
    private func requireChild() -> ChildProfile {
        guard let activeChild else {
            preconditionFailure("Navigated to a child destination with no active child")
        }
        return activeChild
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
