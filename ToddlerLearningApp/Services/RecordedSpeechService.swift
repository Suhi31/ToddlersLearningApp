//
//  RecordedSpeechService.swift
//  ToddlerLearningApp
//
//  The second SpeechServicing conformance SpeechService.swift's header
//  comment already anticipated: plays real bundled voice clips instead of
//  synthesizing speech, falling back to the synthesized `SpeechService` for
//  any moment that hasn't been recorded yet — so content can be filled in
//  incrementally, one letter or one praise line at a time, without ever
//  leaving a gap in coverage. With zero clips bundled, every call falls
//  through to `fallback` and behavior is identical to using `SpeechService`
//  directly.
//
//  Falls back per whole teaching *sequence*, not per beat: if a letter's
//  three teaching beats (name, sound, "X is for Word") aren't all recorded,
//  the entire sequence uses synthesized speech instead of switching voices
//  mid-sequence — jarring, and worse than either option alone.
//
//  Bundled resource naming convention (all `.m4a`, dropped anywhere in the
//  app target so Xcode's synchronized group picks them up):
//    letter-<ID>-name.m4a      e.g. letter-A-name.m4a       ("A.")
//    letter-<ID>-phoneme.m4a   e.g. letter-B-phoneme.m4a    ("buh")
//    letter-<ID>-word.m4a      e.g. letter-C-word.m4a       ("C is for Cat")
//    number-<ID>-name.m4a      e.g. number-1-name.m4a       ("One.")
//    number-<ID>-counting.m4a  e.g. number-3-counting.m4a   ("One, two, three")
//    praise-<anything>.m4a     any number of generic praise clips — never
//                              says a name, since arbitrary child names
//                              can't be pre-recorded
//    encourage-<ID>-<anything>.m4a   e.g. encourage-D-1.m4a, one or more
//                                    per letter
//  Coverage can be partial: an uncovered letter/number/moment transparently
//  falls back to TTS, so there's no requirement to record everything before
//  any of it ships.
//

import AVFoundation
import Foundation

@MainActor
final class RecordedSpeechService: SpeechServicing {

    private let fallback: SpeechServicing
    private let bundle: Bundle
    private let player = RecordedClipPlayer()

    /// Gap between beats in a teaching sequence — matches `SpeechService`'s
    /// own `teachingGap` so a recorded sequence paces the same as a
    /// synthesized one.
    private let teachingGap: Double = 1.0

    private var isSoundEnabled: Bool {
        (UserDefaults.standard.object(forKey: SpeechService.soundEnabledKey) as? Bool) ?? true
    }

    init(fallback: SpeechServicing, bundle: Bundle = .main) {
        self.fallback = fallback
        self.bundle = bundle
    }

    // MARK: - Ad hoc prompts

    /// Free-form text has no "moment" to look a recording up by, so this
    /// always goes straight to synthesized speech.
    func speak(_ text: String) {
        fallback.speak(text)
    }

    // MARK: - Letters

    func teachLetter(_ letter: Letter) async {
        guard isSoundEnabled else { return }

        guard let beats = letterBeats(for: letter) else {
            await fallback.teachLetter(letter)
            return
        }

        for (index, url) in beats.enumerated() {
            await player.playAndWait(url: url)
            if index < beats.count - 1 {
                guard await pause(seconds: teachingGap) else { return }
            }
        }
    }

    private func letterBeats(for letter: Letter) -> [URL]? {
        let clips = ["name", "phoneme", "word"].map { "letter-\(letter.id)-\($0)" }
            .compactMap { clipURL(named: $0) }
        return clips.count == 3 ? clips : nil
    }

    // MARK: - Numbers

    func teachNumber(_ number: NumberItem) async {
        guard isSoundEnabled else { return }

        guard let beats = numberBeats(for: number) else {
            await fallback.teachNumber(number)
            return
        }

        for (index, url) in beats.enumerated() {
            await player.playAndWait(url: url)
            if index < beats.count - 1 {
                guard await pause(seconds: teachingGap) else { return }
            }
        }
    }

    private func numberBeats(for number: NumberItem) -> [URL]? {
        let clips = ["name", "counting"].map { "number-\(number.id)-\($0)" }
            .compactMap { clipURL(named: $0) }
        return clips.count == 2 ? clips : nil
    }

    // MARK: - Praise / encourage

    func praise(childName: String?) {
        guard isSoundEnabled else { return }

        guard let clip = clips(matchingPrefix: "praise-").randomElement() else {
            fallback.praise(childName: childName)
            return
        }
        Task { await player.playAndWait(url: clip) }
    }

    func encourage(_ letter: Letter) {
        guard isSoundEnabled else { return }

        guard let clip = clips(matchingPrefix: "encourage-\(letter.id)-").randomElement() else {
            fallback.encourage(letter)
            return
        }
        Task { await player.playAndWait(url: clip) }
    }

    func stop() {
        player.stop()
        fallback.stop()
    }

    // MARK: - Sequencing

    private func pause(seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }

    // MARK: - Bundle lookup

    private func clipURL(named name: String) -> URL? {
        bundle.url(forResource: name, withExtension: "m4a")
    }

    private func clips(matchingPrefix prefix: String) -> [URL] {
        (bundle.urls(forResourcesWithExtension: "m4a", subdirectory: nil) ?? [])
            .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix(prefix) }
    }
}

/// Plays one bundled audio file at a time, awaitable so a caller can pace a
/// multi-beat sequence against real playback duration — same role
/// `SpeechEngine.speakAndWait` plays for synthesized speech, but far simpler
/// since a plain audio file has none of `AVSpeechSynthesisVoice`'s blocking
/// asset-lookup problem, so this needs no dedicated queue.
@MainActor
private final class RecordedClipPlayer: NSObject, AVAudioPlayerDelegate {

    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Never>?

    func playAndWait(url: URL) async {
        stop()

        await withCheckedContinuation { continuation in
            do {
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.delegate = self
                player = newPlayer
                self.continuation = continuation
                newPlayer.play()
            } catch {
                continuation.resume()
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        finishCurrent()
    }

    private func finishCurrent() {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.finishCurrent() }
    }
}
