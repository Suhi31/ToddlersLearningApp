//
//  RecordedSpeechService.swift
//  ToddlerLearningApp
//
//  The second SpeechServicing conformance SpeechService.swift's header
//  comment already anticipated: plays real bundled voice clips instead of
//  synthesizing speech, falling back to the synthesized `SpeechService` for
//  any moment that hasn't been recorded yet — so content can be filled in
//  incrementally, one letter or number at a time, without ever
//  leaving a gap in coverage. With zero clips bundled, every call falls
//  through to `fallback` and behavior is identical to using `SpeechService`
//  directly.
//
//  Teaching sequences (`teachLetter`, `teachNumber`) fall back per whole
//  *sequence*, not per beat: if a letter's three beats (name, sound, "X is for
//  Word") aren't all recorded, the entire sequence is synthesized rather than
//  switching voices mid-lesson.
//
//  Ordinary lines (`speak`, `speakAndWait`) fall back per *line* instead, which
//  is a deliberate difference. Praise is the reason: "Woohoo, Mih!" contains a
//  name typed by a parent and can never be a recording, while the line after it
//  — "That's the letter A." — can. Holding the whole sequence to the weakest
//  line would mean every correct answer in the app stayed synthesized. So the
//  child does sometimes hear the synthesizer and the recorded voice in one
//  breath; that is the accepted cost of keeping praise personal.
//
//  Bundled resource naming convention (all `.m4a`, dropped anywhere in the
//  app target so Xcode's synchronized group picks them up):
//    letter-<ID>-name.m4a      e.g. letter-A-name.m4a       ("A.")
//    letter-<ID>-phoneme.m4a   e.g. letter-B-phoneme.m4a    ("buh")
//    letter-<ID>-word.m4a      e.g. letter-C-word.m4a       ("C is for Cat")
//    number-<ID>-name.m4a      e.g. number-1-name.m4a       ("Number one.")
//    number-<ID>-counting.m4a  e.g. number-3-counting.m4a   ("One, two, three")
//    number-<ID>-counting.json when each number starts in that clip — see
//                              `countingOnsets(for:in:)`
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

    /// Gap between the sentences of one spoken line — matches
    /// `SpeechService.sentenceGap` so a recorded line and a synthesized one
    /// are paced the same.
    private let sentenceGap: Double = 0.35

    /// Gap between beats in a teaching sequence. Deliberately shorter than
    /// `SpeechService`'s own 1.0s: a synthesized utterance trails off with
    /// silence of its own, so the same nominal gap sounds far longer between
    /// two recordings, which are trimmed tight to the first and last sound.
    /// At 1.0s the letter lesson had roughly two seconds of dead air between
    /// "A" and its sound, which reads as the app having stopped working.
    private let teachingGap: Double = 0.55

    /// Same role as `SpeechService.generation`: bumped by every `stop()`,
    /// which every line starts with, so a clip sequence that has been talked
    /// over gives up at its next gap instead of carrying on underneath.
    private var generation = 0

    private var isSoundEnabled: Bool {
        (UserDefaults.standard.object(forKey: SpeechService.soundEnabledKey) as? Bool) ?? true
    }

    init(fallback: SpeechServicing, bundle: Bundle = .main) {
        self.fallback = fallback
        self.bundle = bundle
    }

    // MARK: - Ad hoc prompts

    /// Plays the line's recording if it has one, else synthesizes it.
    /// Fire-and-forget, like `SpeechService.speak`.
    func speak(_ line: SpokenLine) {
        guard isSoundEnabled else { return }
        stop()

        guard let url = line.clip.flatMap(clipURL(named:)) else {
            fallback.speak(line)
            return
        }

        let sequence = generation
        Task { [player] in
            guard sequence == generation else { return }
            await player.playAndWait(url: url)
        }
    }

    /// Each line independently: recorded if a clip exists for it, synthesized
    /// if not. See the header for why this is per line rather than per
    /// sequence.
    func speakAndWait(_ sentences: [SpokenLine]) async {
        guard isSoundEnabled else { return }
        stop()
        let sequence = generation

        for (index, line) in sentences.enumerated() {
            if index > 0 {
                guard await pause(seconds: sentenceGap, sequence: sequence) else { return }
            }

            if let url = line.clip.flatMap(clipURL(named:)) {
                await player.playAndWait(url: url)
            } else {
                // One line at a time, so a keyless line in the middle doesn't
                // drag the recorded ones around it into synthesis too.
                await fallback.speakAndWait([line])
            }

            guard sequence == generation, !Task.isCancelled else { return }
        }
    }

    // MARK: - Letters

    func teachLetter(_ letter: Letter) async {
        guard isSoundEnabled else { return }
        stop()
        let sequence = generation

        guard let beats = letterBeats(for: letter) else {
            await fallback.teachLetter(letter)
            return
        }

        for (index, url) in beats.enumerated() {
            await player.playAndWait(url: url)
            if index < beats.count - 1 {
                guard await pause(seconds: teachingGap, sequence: sequence) else { return }
            }
        }
    }

    private func letterBeats(for letter: Letter) -> [URL]? {
        let clips = ["name", "phoneme", "word"].map { "letter-\(letter.id)-\($0)" }
            .compactMap { clipURL(named: $0) }
        return clips.count == 3 ? clips : nil
    }

    // MARK: - Numbers

    /// Two beats, like the synthesized lesson: "Number three.", then "One,
    /// two, three." The name says "Number five." rather than "Five." because
    /// this voice turns a lone "five" into "fives".
    ///
    /// The counting recording is one clip, so it has no timing of its own for
    /// `onCount`. That comes from its timing file instead: the moment each
    /// number starts, fired as playback reaches it, so objects still light up
    /// in time with the voice.
    func teachNumber(_ number: NumberItem, onCount: @escaping @MainActor (Int?) -> Void) async {
        guard isSoundEnabled else { return }
        stop()
        let sequence = generation

        guard let name = clipURL(named: "number-\(number.id)-name"),
              let counting = clipURL(named: "number-\(number.id)-counting") else {
            await fallback.teachNumber(number, onCount: onCount)
            return
        }

        await player.playAndWait(url: name)
        guard await pause(seconds: teachingGap, sequence: sequence) else { return }

        await player.playAndWait(url: counting,
                                 cues: Self.countingOnsets(for: number, in: bundle)) { index in
            onCount(index + 1)
        }
        // Also when talked over, so no object is left lit.
        onCount(nil)
    }

    /// Seconds into `number-<ID>-counting` at which each number starts — the
    /// first entry is "one" — measured from the clip by
    /// tools/gen_count_timings.py.
    ///
    /// Empty if the file is missing or doesn't fit this number. The count then
    /// plays with nothing lit, which beats switching voice to get the
    /// highlight back; `check_keys.py` fails on it, so it isn't shipped that
    /// way by accident.
    static func countingOnsets(for number: NumberItem, in bundle: Bundle) -> [TimeInterval] {
        struct Timing: Decodable {
            let onsets: [TimeInterval]
        }

        guard let url = bundle.url(forResource: "number-\(number.id)-counting", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let timing = try? JSONDecoder().decode(Timing.self, from: data),
              timing.onsets.count == number.id
        else { return [] }
        return timing.onsets
    }

    func stop() {
        generation += 1
        player.stop()
        fallback.stop()
    }

    // MARK: - Sequencing

    private func pause(seconds: Double, sequence: Int) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled && sequence == generation
    }

    // MARK: - Bundle lookup

    private func clipURL(named name: String) -> URL? {
        bundle.url(forResource: name, withExtension: "m4a")
    }
}

/// Plays one bundled audio file at a time, awaitable so a caller can pace a
/// multi-beat sequence against real playback duration — same role
/// `SpeechEngine.speakAndWait` plays for synthesized speech, but far simpler
/// since a plain audio file has none of `AVSpeechSynthesisVoice`'s blocking
/// asset-lookup problem, so this needs no dedicated queue.
@MainActor
private final class RecordedClipPlayer: NSObject, AVAudioPlayerDelegate {

    /// Clips play slower than they were recorded, because a toddler needs time
    /// to follow the words.
    ///
    /// This is deliberately done here rather than when the audio is generated.
    /// Asking the voice model for slow speech corrupts it — at 0.8 it prepends
    /// a schwa, turning "Trace B" into "a-Trace B" and a lone "Bee" into "a B"
    /// — so clips are generated at the model's natural pace, where it behaves,
    /// and stretched at playback with the pitch preserved. It also makes the
    /// speed a one-line change instead of regenerating ~1,500 files.
    private static let playbackRate: Float = 0.8

    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Never>?
    private var cueTask: Task<Void, Never>?

    /// `cues` are moments in the clip, in seconds of the recording as it was
    /// generated, and `onCue` is told the index of each one as playback
    /// reaches it. Cues not yet reached when the clip ends or is stopped never
    /// fire.
    func playAndWait(url: URL,
                     cues: [TimeInterval] = [],
                     onCue: @escaping @MainActor (Int) -> Void = { _ in }) async {
        stop()

        await withCheckedContinuation { continuation in
            do {
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.delegate = self
                // `enableRate` has to be set before the player prepares its
                // buffers, or `rate` is silently ignored.
                newPlayer.enableRate = true
                newPlayer.prepareToPlay()
                newPlayer.rate = Self.playbackRate
                player = newPlayer
                self.continuation = continuation
                newPlayer.play()
                if !cues.isEmpty {
                    cueTask = Task { await Self.follow(cues, on: newPlayer, onCue: onCue) }
                }
            } catch {
                continuation.resume()
            }
        }
    }

    /// Watches the player's own position rather than scheduling each cue on
    /// a timer up front. The cues are clip time, and playback is slowed and
    /// takes a moment to start, so a timer would drift; the position doesn't.
    private static func follow(_ cues: [TimeInterval],
                               on player: AVAudioPlayer,
                               onCue: @MainActor (Int) -> Void) async {
        var next = 0
        while next < cues.count, !Task.isCancelled {
            // Everything already passed fires, so a late tick can't skip one.
            while next < cues.count, player.currentTime >= cues[next] {
                onCue(next)
                next += 1
            }
            try? await Task.sleep(for: .milliseconds(15))
        }
    }

    func stop() {
        player?.stop()
        player = nil
        finishCurrent()
    }

    private func finishCurrent() {
        cueTask?.cancel()
        cueTask = nil
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.finishCurrent() }
    }
}
