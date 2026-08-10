//
//  RootView.swift
//  ToddlerLearningApp
//
//  Hosts the single NavigationStack and decides between onboarding and the main
//  experience. This is the only view that knows both exist.
//

import SwiftData
import SwiftUI

struct RootView: View {

    @Environment(\.scenePhase) private var scenePhase

    /// Sorted oldest-first as a deterministic fallback for `resumeSavedProfile`
    /// when there's no last-active child to resume (first launch, or that
    /// child was deleted) — see `AppCoordinator.lastActiveChildID()`.
    @Query(sort: \ChildProfile.createdAt, order: .forward)
    private var children: [ChildProfile]

    @State private var coordinator: AppCoordinator

    init(dependencies: AppDependencies) {
        _coordinator = State(initialValue: AppCoordinator(dependencies: dependencies))
    }

    var body: some View {
        ZStack {
            if let activeChild = coordinator.activeChild {
                mainFlow(for: activeChild)
            } else {
                OnboardingView(
                    viewModel: OnboardingViewModel(
                        modelContext: coordinator.dependencies.modelContext,
                        progressService: coordinator.dependencies.progressService
                    ),
                    coordinator: coordinator
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.isOnboarded)
        .onAppear(perform: resumeSavedProfile)
        .onChange(of: scenePhase) { _, phase in
            handle(phase)
        }
        .fullScreenCover(isPresented: $coordinator.showTimeUp) {
            TimeUpView(childName: coordinator.activeChild?.name ?? "") {
                coordinator.dismissTimeUp()
            }
        }
    }

    private func mainFlow(for child: ChildProfile) -> some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(
                viewModel: HomeViewModel(
                    child: child,
                    sessionTimer: coordinator.sessionTimer,
                    speechService: coordinator.dependencies.speechService,
                    haptics: coordinator.dependencies.haptics
                ),
                coordinator: coordinator
            )
            .navigationDestination(for: Route.self) { route in
                coordinator.destination(for: route)
            }
        }
        .sheet(item: $coordinator.sheet) { sheet in
            switch sheet {
            case .switchChild:
                ChildPickerView(coordinator: coordinator)
            }
        }
        // Forces SwiftUI to tear down and rebuild this subtree (including
        // HomeView's @State viewModel) when the active child changes —
        // without this, switching children left Home showing the previous
        // child's name/stats since the view's identity never changed.
        .id(child.id)
    }

    // MARK: - Lifecycle

    /// Spec F1: a saved profile means no child ever sees onboarding twice. In a
    /// household with siblings this resumes whichever child was active last,
    /// not just the oldest profile — falling back to the oldest if there's no
    /// recorded last-active child or it was since deleted.
    private func resumeSavedProfile() {
        guard !coordinator.isOnboarded else { return }
        let lastActiveID = AppCoordinator.lastActiveChildID()
        guard let resumed = children.first(where: { $0.id == lastActiveID }) ?? children.first else { return }
        coordinator.start(with: resumed)
    }

    private func handle(_ phase: ScenePhase) {
        switch phase {
        case .active:
            coordinator.resumeSession()
        case .inactive, .background:
            // Only foreground time counts against the daily allowance.
            coordinator.endSession()
        @unknown default:
            break
        }
    }
}
