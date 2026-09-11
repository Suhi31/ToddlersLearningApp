//
//  RhymeAudioService.swift
//  ToddlerLearningApp
//
//  Rhymes need real sung/recorded audio — AVSpeechSynthesizer (SpeechService)
//  can't sing — so this is a second, parallel playback path abstracted behind
//  its own protocol, same reasoning as SpeechServicing: call sites depend on
//  RhymeAudioPlaying, not AVAudioPlayer directly.
//
//  Licensed/public-domain recordings are not bundled yet — sourcing them and
//  adding them to a Resources/RhymeAudio folder reference is a content task,
//  not an engineering one — see docs/PRODUCT_SPEC.md. Until then, `play(_:)`
//  falls back to reading the lyric lines aloud with AVSpeechSynthesizer, one
//  line at a time, so the feature works end-to-end rather than playing
//  silence. This is a placeholder, not a real "sing along" — swap it out the
//  moment a bundled clip exists for a given rhyme.
//
//  This service only knows about audio playback. Silencing any in-flight
//  SpeechService utterance before a rhyme starts is RhymeDetailViewModel's job
//  — it already holds both services, so that coordination belongs there rather
//  than as a dependency between two otherwise-unrelated leaf services.
//
//  `@Observable` so `isPlaying`/`progress` drive SwiftUI directly. Before, the
//  detail view model polled these five times a second for the whole time the
//  screen was open, playing or not, purely because this type wasn't observable.
//

import AVFoundation
import Foundation

@MainActor
protocol RhymeAudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    /// 0...1 through the current track, for a scrub bar and line-highlight
    /// approximation in the detail view.
    var progress: Double { get }
    /// Called when a track ends of its own accord. See the implementation.
    var onFinished: (() -> Void)? { get set }
    func play(_ rhyme: Rhyme)
    func pause()
    func resume()
    func stop()
}

@MainActor
@Observable
final class RhymeAudioService: NSObject, RhymeAudioPlaying {

    private(set) var isPlaying = false
    private(set) var progress: Double = 0

    /// Fired when a track reaches its natural end — not on `pause()` or an
    /// explicit `stop()`. This is what the detail view model used to infer by
    /// watching for a playing→stopped-at-zero transition through its poll loop.
    @ObservationIgnored var onFinished: (() -> Void)?

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var progressTimer: Timer?

    /// Toddler-comfortable rate, matching `SpeechService`'s own tuning — kept
    /// as a separate constant rather than shared, since the two services
    /// deliberately don't know about each other (see header comment above).
    private let synthesisRate: Float = 0.42

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var synthesizedLines: [String] = []
    @ObservationIgnored private var currentLineIndex = 0
    @ObservationIgnored private var isSynthesizing = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func play(_ rhyme: Rhyme) {
        let name = rhyme.audioFileName as NSString
        guard let url = Bundle.main.url(
            forResource: name.deletingPathExtension,
            withExtension: name.pathExtension
        ) else {
            playSynthesized(rhyme)
            return
        }

        do {
            configureAudioSession()
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            player = newPlayer
            newPlayer.play()
            isPlaying = true
            progress = 0
            startProgressTimer()
        } catch {
            stop()
        }
    }

    func pause() {
        if isSynthesizing {
            synthesizer.pauseSpeaking(at: .word)
        } else {
            player?.pause()
        }
        isPlaying = false
        stopProgressTimer()
    }

    func resume() {
        if isSynthesizing {
            isPlaying = true
            synthesizer.continueSpeaking()
            return
        }
        guard let player else { return }
        player.play()
        isPlaying = true
        startProgressTimer()
    }

    func stop() {
        if isSynthesizing {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSynthesizing = false
        synthesizedLines = []
        currentLineIndex = 0
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        stopProgressTimer()
    }

    // MARK: - Synthesized placeholder (no bundled recording yet)

    private func playSynthesized(_ rhyme: Rhyme) {
        stop()
        guard !rhyme.lines.isEmpty else { return }

        configureAudioSession()
        synthesizedLines = rhyme.lines
        currentLineIndex = 0
        isSynthesizing = true
        isPlaying = true
        progress = 0
        speakCurrentLine()
    }

    private func speakCurrentLine() {
        guard currentLineIndex < synthesizedLines.count else {
            finishSynthesizing()
            return
        }
        let utterance = AVSpeechUtterance(string: synthesizedLines[currentLineIndex])
        utterance.rate = synthesisRate
        utterance.pitchMultiplier = 1.15
        synthesizer.speak(utterance)
    }

    private func advanceToNextLine() {
        guard isSynthesizing else { return }
        currentLineIndex += 1
        if currentLineIndex >= synthesizedLines.count {
            finishSynthesizing()
        } else {
            progress = Double(currentLineIndex) / Double(synthesizedLines.count)
            speakCurrentLine()
        }
    }

    /// `onFinished` fires here too, same as the natural end of a recorded
    /// clip — see the protocol doc.
    private func finishSynthesizing() {
        isSynthesizing = false
        isPlaying = false
        progress = 0
        onFinished?()
    }

    private func updateSynthesisProgress(range: NSRange, in text: String) {
        guard isSynthesizing, !synthesizedLines.isEmpty else { return }
        let length = (text as NSString).length
        guard length > 0 else { return }
        let withinLine = Double(range.location) / Double(length)
        progress = (Double(currentLineIndex) + withinLine) / Double(synthesizedLines.count)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateProgress() }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard let player, player.duration > 0 else { return }
        progress = player.currentTime / player.duration
    }
}

extension RhymeAudioService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            stop()
            onFinished?()
        }
    }
}

extension RhymeAudioService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                        willSpeakRangeOfSpeechString characterRange: NSRange,
                                        utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.updateSynthesisProgress(range: characterRange, in: utterance.speechString)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                        didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.advanceToNextLine()
        }
    }
}
