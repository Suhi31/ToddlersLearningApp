//
//  RhymeAudioService.swift
//  ToddlerLearningApp
//
//  Rhymes need real sung/recorded audio — AVSpeechSynthesizer (SpeechService)
//  can't sing — so this is a second, parallel playback path abstracted behind
//  its own protocol, same reasoning as SpeechServicing: call sites depend on
//  RhymeAudioPlaying, not AVAudioPlayer directly.
//
//  Audio files are not bundled yet. Sourcing licensed or public-domain
//  recordings and adding them to a Resources/RhymeAudio folder reference is a
//  content task, not an engineering one — see docs/PRODUCT_SPEC.md. Until
//  then `play(_:)` fails silently: a missing clip should never crash or block
//  the UI, only produce silence.
//
//  This service only knows about audio playback. Silencing any in-flight
//  SpeechService utterance before a rhyme starts is RhymesViewModel's job —
//  it already holds both services, so that coordination belongs there rather
//  than as a dependency between two otherwise-unrelated leaf services.
//

import AVFoundation
import Foundation

@MainActor
protocol RhymeAudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    /// 0...1 through the current track, for a scrub bar and line-highlight
    /// approximation in the detail view.
    var progress: Double { get }
    func play(_ rhyme: Rhyme)
    func pause()
    func resume()
    func stop()
}

@MainActor
final class RhymeAudioService: NSObject, RhymeAudioPlaying {

    private(set) var isPlaying = false
    private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    func play(_ rhyme: Rhyme) {
        let name = rhyme.audioFileName as NSString
        guard let url = Bundle.main.url(
            forResource: name.deletingPathExtension,
            withExtension: name.pathExtension
        ) else {
            stop()
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
        player?.pause()
        isPlaying = false
        stopProgressTimer()
    }

    func resume() {
        guard let player else { return }
        player.play()
        isPlaying = true
        startProgressTimer()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        stopProgressTimer()
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
            self?.stop()
        }
    }
}
