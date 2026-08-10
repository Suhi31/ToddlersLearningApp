//
//  BrowsingViewModel.swift
//  ToddlerLearningApp
//
//  Shared engine behind Learn Letters and Learn Numbers: page through a fixed
//  list of items, teaching the current one via speech, and let the child jump
//  straight to any item from a strip. The two domains differ only in what an
//  "item" is and how it's taught — paging, haptics, and the speech-task
//  lifecycle are identical, so that part lives here once.
//

import Foundation

@MainActor
@Observable
final class BrowsingViewModel<Item: Equatable> {

    private(set) var currentIndex: Int = 0

    /// Fired on navigating to a different item — a natural break where the
    /// daily allowance may end the session (spec F5), same convention as
    /// QuizEngineViewModel. The view wires this to the coordinator; this
    /// class stays navigation-agnostic.
    var onSafeStoppingPoint: (() -> Void)?

    let child: ChildProfile
    let items: [Item]

    private let speechService: SpeechServicing
    private let haptics: HapticsService
    private let masteryProvider: (Item) -> MasteryLevel
    private let exposureRecorder: (Item) -> Void
    private let teacher: (Item) async -> Void

    private var speechTask: Task<Void, Never>?

    deinit {}

    init(child: ChildProfile,
         items: [Item],
         startIndex: Int = 0,
         speechService: SpeechServicing,
         haptics: HapticsService,
         mastery: @escaping (Item) -> MasteryLevel,
         recordExposure: @escaping (Item) -> Void,
         teach: @escaping (Item) async -> Void) {
        self.child = child
        self.items = items
        self.speechService = speechService
        self.haptics = haptics
        self.masteryProvider = mastery
        self.exposureRecorder = recordExposure
        self.teacher = teach
        self.currentIndex = items.indices.contains(startIndex) ? startIndex : 0
    }

    var current: Item? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < items.count - 1 }

    var positionCaption: String {
        "\(currentIndex + 1) of \(items.count)"
    }

    func mastery(for item: Item) -> MasteryLevel {
        masteryProvider(item)
    }

    // MARK: - Intent

    func onAppear() {
        haptics.prepare()
        announceCurrent()
    }

    func onDisappear() {
        speechTask?.cancel()
        speechService.stop()
    }

    func next() {
        guard canGoForward else { return }
        currentIndex += 1
        haptics.tap()
        announceCurrent()
        onSafeStoppingPoint?()
    }

    func previous() {
        guard canGoBack else { return }
        currentIndex -= 1
        haptics.tap()
        announceCurrent()
        onSafeStoppingPoint?()
    }

    func jump(to item: Item) {
        guard let index = items.firstIndex(of: item) else { return }
        currentIndex = index
        haptics.tap()
        announceCurrent()
        onSafeStoppingPoint?()
    }

    /// Replays the same teach sequence — this is a learning screen, not a quiz,
    /// so there is no "your turn" prompt here, only repetition.
    func repeatSound() {
        haptics.tap()
        announceCurrent(recordExposure: false)
    }

    private func announceCurrent(recordExposure shouldRecord: Bool = true) {
        guard let current else { return }

        if shouldRecord {
            exposureRecorder(current)
        }

        speechTask?.cancel()
        speechService.stop()
        speechTask = Task { [teacher, current] in
            await teacher(current)
        }
    }
}

// MARK: - Learn Letters

typealias LearnAlphabetViewModel = BrowsingViewModel<Letter>

extension BrowsingViewModel where Item == Letter {

    /// Learn is free exploration, not gated by age like Quiz is (spec F2) — a
    /// child should be able to page through the whole alphabet here even if
    /// only some letters are unlocked for quizzing yet.
    convenience init(child: ChildProfile,
                      startingItem: Letter? = nil,
                      speechService: SpeechServicing,
                      progressService: ProgressService,
                      haptics: HapticsService) {
        self.init(
            child: child,
            items: AlphabetContent.letters,
            startIndex: startingItem.flatMap { AlphabetContent.letters.firstIndex(of: $0) } ?? 0,
            speechService: speechService,
            haptics: haptics,
            mastery: { child.progress(for: $0.id)?.mastery ?? .new },
            recordExposure: { progressService.recordExposure(child: child, letterID: $0.id) },
            teach: { await speechService.teachLetter($0) }
        )
    }

    var letters: [Letter] { items }
    var currentLetter: Letter? { current }
}

// MARK: - Learn Numbers

typealias LearnNumbersViewModel = BrowsingViewModel<NumberItem>

extension BrowsingViewModel where Item == NumberItem {

    /// Numbers-domain twin of the letters initializer above — free
    /// exploration, same rationale as Learn Letters.
    convenience init(child: ChildProfile,
                      startingItem: NumberItem? = nil,
                      speechService: SpeechServicing,
                      progressService: ProgressService,
                      haptics: HapticsService) {
        self.init(
            child: child,
            items: NumberContent.numbers,
            startIndex: startingItem.flatMap { NumberContent.numbers.firstIndex(of: $0) } ?? 0,
            speechService: speechService,
            haptics: haptics,
            mastery: { child.numberProgress(for: $0.id)?.mastery ?? .new },
            recordExposure: { progressService.recordExposure(child: child, numberID: $0.id) },
            teach: { await speechService.teachNumber($0) }
        )
    }

    var numbers: [NumberItem] { items }
    var currentNumber: NumberItem? { current }
}
