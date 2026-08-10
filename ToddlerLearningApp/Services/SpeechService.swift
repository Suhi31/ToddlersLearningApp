//
//  SpeechService.swift
//  ToddlerLearningApp
//
//  Spec F6. Every spoken line in the app goes through this protocol. Synthesised
//  speech ships in v1; swapping in the 26 recorded clips later is a matter of
//  adding a second conformance, with no call sites touched.
//

import AVFoundation
import Foundation

@MainActor
protocol SpeechServicing: AnyObject {
    func speak(_ text: String)
    /// Teaches a letter as three separate beats — name, then sound, then the
    /// word — each a full second apart, for the Learn screen only.
    func teachLetter(_ letter: Letter) async
    /// Teaches a number as two beats — its name, then counting up to it — for
    /// the Learn Numbers screen only.
    func teachNumber(_ number: NumberItem) async
    func praise(childName: String?)
    func encourage(_ letter: Letter)
    func stop()
}

/// Everything needed to render one spoken line, in a form that can be handed
/// across to the engine queue. The `AVSpeechUtterance` itself is deliberately
/// *not* built here: attaching a voice to an utterance can reach into the same
/// asset lookup that `SpeechEngine` exists to keep off the main thread, so
/// construction belongs on the engine's queue alongside every other
/// AVFoundation call.
private struct SpeechRequest: Sendable {
    let text: String
    /// IPA notation applied across the whole string, when the plain spelling
    /// doesn't survive the text normalizer. See `ipaOverrides`.
    var ipa: String? = nil
    let rate: Float
    var pitchMultiplier: Float = 1.15
    var volume: Float = 1.0
}

@MainActor
final class SpeechService: SpeechServicing {

    /// Shared with the Settings sound toggle via `@AppStorage`. Not wrapped in
    /// `@AppStorage` here since this class has no need to react to changes —
    /// it only needs the current value at the moment it's about to speak.
    static let soundEnabledKey = "isSoundEnabled"

    private var isSoundEnabled: Bool {
        (UserDefaults.standard.object(forKey: Self.soundEnabledKey) as? Bool) ?? true
    }

    /// Slightly under the default rate. Full speed is too fast to be intelligible
    /// to a child still mapping sounds to letters.
    private let rate: Float = 0.42

    /// Gap between beats in `teachLetter`. AVSpeechSynthesizer has no notion of
    /// a pause inside one utterance, so teaching a letter is really three
    /// utterances spoken in sequence with a deliberate silence between them.
    private let teachingGap: Double = 1.0

    /// A handful of letter sounds are continuant consonants or clusters whose
    /// plain-text spelling — "ff", "zz", "ks" — isn't a real English word, so
    /// AVSpeechSynthesizer's text normalizer either spells it out letter by
    /// letter ("zz" → "Zee Zee") or garbles it. Those get an explicit IPA
    /// pronunciation instead. Every other letter's spelled-out phoneme
    /// ("buh", "kuh", ...) already reads correctly as a nonsense syllable, so
    /// it's left alone rather than risk changing a sound that already works.
    ///
    /// Each override is lengthened (ː) with a soft trailing schwa: a bare
    /// isolated phone is a near-instantaneous, low-energy blip — "ɹ" alone is
    /// close to inaudible, since an approximant only really registers next to
    /// a vowel — so the schwa gives the engine something with real acoustic
    /// energy to render, and the length mark keeps it from being clipped short.
    private let ipaOverrides: [String: String] = [
        "F": "fːə",
        "L": "lːə",
        "M": "mːə",
        "N": "nːə",
        "R": "ɹːə",
        "S": "sːə",
        "V": "vːə",
        "X": "ksːə",
        "Z": "zːə"
    ]

    /// Slower than normal speech and at full volume — an isolated consonant
    /// sound is easy to miss at conversational pace, and this is the one
    /// beat in the whole app that most needs to be heard clearly.
    private let phonemeRate: Float = 0.32

    /// Owns the synthesizer and every call made against it. This type holds no
    /// AVFoundation state of its own — see `SpeechEngine` for why none of it
    /// can safely live on the main actor.
    private let engine = SpeechEngine()

    func speak(_ text: String) {
        guard isSoundEnabled else { return }
        stop()
        // A small random wobble in rate/pitch, not the teaching beats below —
        // the exact same flat cadence on every single prompt/praise line is
        // as much of what reads as "robotic" as voice quality itself.
        engine.speak(SpeechRequest(text: text, rate: playfulRate(), pitchMultiplier: playfulPitch()))
    }

    func teachLetter(_ letter: Letter) async {
        guard isSoundEnabled else { return }
        stop()

        // A bare single-character utterance makes AVSpeechSynthesizer spell it
        // out and prefix "capital" to disambiguate case — appending a period
        // keeps the string from being read as exactly one letter, so it just
        // says the letter name.
        await engine.speakAndWait(SpeechRequest(text: "\(letter.uppercase).", rate: rate))
        guard await pause(seconds: teachingGap) else { return }

        await engine.speakAndWait(phonemeRequest(for: letter))
        guard await pause(seconds: teachingGap) else { return }

        // Same reasoning as above: "A is for Apple" gets normalized as the
        // indefinite article "a" (the "uh" sound) rather than the letter
        // name — the period keeps it a distinct sentence read as the letter.
        await engine.speakAndWait(
            SpeechRequest(text: "\(letter.uppercase). is for \(letter.word)", rate: rate)
        )
    }

    func teachNumber(_ number: NumberItem) async {
        guard isSoundEnabled else { return }
        stop()

        await engine.speakAndWait(SpeechRequest(text: "\(number.name).", rate: rate))
        guard await pause(seconds: teachingGap) else { return }

        // Counting up to the number is the actual pedagogy — recognising the
        // numeral alone doesn't teach quantity the way saying "one, two,
        // three" while looking at three objects does.
        let count = (1...number.id)
            .map { NumberContent.number(id: $0)?.name ?? "\($0)" }
            .joined(separator: ", ")
        await engine.speakAndWait(SpeechRequest(text: count, rate: rate))
    }

    func praise(childName: String?) {
        let options = [
            "Great job", "Well done", "You got it", "Nice work", "Brilliant",
            "Woohoo", "Fantastic", "You're a star", "Ta-da", "Amazing",
            "Super job", "Way to go", "You nailed it", "High five"
        ]
        var phrase = options.randomElement() ?? "Great job"
        if let childName, !childName.isEmpty {
            phrase += ", \(childName)"
        }
        speak(phrase + "!")
    }

    /// Deliberately never says "wrong". At this age a miss should redirect
    /// attention, not register as failure. Several phrasings rather than one
    /// fixed sentence, same reasoning as the variety in `praise`.
    func encourage(_ letter: Letter) {
        let phrasings = [
            "This one is \(letter.uppercase). It's for \(letter.word). Let's try again.",
            "That's okay! This is \(letter.uppercase), for \(letter.word). Try again.",
            "Almost! This letter is \(letter.uppercase), like \(letter.word). One more try.",
            "So close! \(letter.uppercase) is for \(letter.word). Let's give it another go."
        ]
        speak(phrasings.randomElement() ?? phrasings[0])
    }

    func stop() {
        engine.stop()
    }

    // MARK: - Sequencing

    /// Sleeps for `seconds`, returning `false` if the surrounding task was
    /// cancelled meanwhile so callers can abandon the rest of a sequence.
    private func pause(seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }

    private func phonemeRequest(for letter: Letter) -> SpeechRequest {
        SpeechRequest(text: letter.phoneme,
                      ipa: ipaOverrides[letter.id],
                      rate: ipaOverrides[letter.id] == nil ? rate : phonemeRate,
                      volume: 1.0)
    }

    /// A narrow wobble around the base rate — enough to sound bouncy rather
    /// than metronomic, not so much that a word ever gets hard to follow.
    private func playfulRate() -> Float {
        Float.random(in: (rate - 0.04)...(rate + 0.04))
    }

    /// Same idea for pitch. Kept above 1.0 (the fixed value every beat used
    /// to have) since a slightly higher pitch reads as friendlier to a
    /// toddler than the synthesizer's flat default.
    private func playfulPitch() -> Float {
        Float.random(in: 1.08...1.28)
    }
}

// MARK: - Engine

/// Confines the synthesizer, its voice, the audio session, and every call made
/// against them to one serial queue.
///
/// The reason is that none of those calls can be trusted to return promptly.
/// `AVSpeechSynthesisVoice(language:)`, `AVSpeechSynthesizer()`, and the first
/// `speak(_:)` all reach the same voice-asset lookup, which blocks its caller
/// synchronously. Sampling this app showed `AVSpeechSynthesisVoice.init` alone
/// holding its thread for 486 of 573 samples on a device whose MobileAsset
/// voice queries were failing (`Query for …VoiceServices.GryphonVoice failed`
/// in the log). On `@MainActor` a stall like that is a frozen app: no touch,
/// no scroll, until the lookup returns.
///
/// Note that this is a plain `DispatchQueue`, deliberately not an `actor` and
/// not a `Task`. Both of those run on Swift concurrency's cooperative pool,
/// which sizes itself to the core count and assumes its threads never block —
/// blocking one starves everything else queued behind it, and is what the
/// `unsafeForcedSync called from Swift Concurrent context` runtime warning in
/// this app's logs is complaining about. A dedicated queue can sit blocked
/// indefinitely without costing the rest of the process anything.
private final class SpeechEngine: NSObject, @unchecked Sendable {

    /// Serial. Every stored property below is confined to it, which is what
    /// makes the `@unchecked Sendable` conformance above honest and what
    /// guarantees `continuation` is resumed exactly once.
    private let queue = DispatchQueue(label: "com.toddlerlearningapp.speech-engine",
                                      qos: .userInitiated)

    private var synthesizer: AVSpeechSynthesizer?

    /// `nil` is a perfectly safe value for `AVSpeechUtterance.voice` —
    /// AVSpeechSynthesizer just falls back to the system default — so a slow
    /// resolve costs quality, never correctness.
    private var voice: AVSpeechSynthesisVoice?

    private var continuation: CheckedContinuation<Void, Never>?

    /// The utterance `continuation` is waiting on. `stopSpeaking` delivers its
    /// `didCancel` callback asynchronously, so by the time one arrives the next
    /// beat of a teaching sequence may already be speaking — matching the
    /// callback's utterance against this one is what stops a stale cancellation
    /// from cutting short the utterance that replaced it.
    private var pendingUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        queue.async { [self] in
            configureAudioSession()
            let resolved = AVSpeechSynthesizer()
            resolved.delegate = self
            synthesizer = resolved
            voice = Self.bestAvailableVoice()
        }
    }

    /// `AVSpeechSynthesisVoice(language:)` just returns whatever the system
    /// picked as the default for that language, which on most devices is the
    /// compact, noticeably synthetic-sounding voice rather than a downloaded
    /// "Enhanced"/"Premium" one — those sound dramatically more natural, and
    /// this picks the best quality actually installed instead of leaving it
    /// to chance. Falls back to the plain default if nothing better is
    /// installed, so behavior never regresses on a device with only the
    /// stock voice.
    private static func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let enUSVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }

        if let premium = enUSVoices.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = enUSVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    private func configureAudioSession() {
        // `.ambient` so the app never interrupts music or a podcast a parent
        // has playing, and `.duckOthers` so speech is still audible over it.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    // MARK: - Speaking

    /// Fire-and-forget. Drops the line rather than queueing it if the engine
    /// is still being built: a line spoken a minute late has lost its
    /// connection to whatever the child tapped, so silence is the better
    /// failure. A child gets a temporarily quiet app, never a frozen one.
    func speak(_ request: SpeechRequest) {
        queue.async { [self] in
            guard let synthesizer else { return }
            finishCurrent()
            synthesizer.speak(makeUtterance(request))
        }
    }

    /// Speaks and returns once the utterance finishes or is cancelled, so the
    /// teaching sequences can time their gaps against real speech rather than
    /// a guess.
    func speakAndWait(_ request: SpeechRequest) async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard let synthesizer else {
                    // Same reasoning as `speak` — don't stall the caller's
                    // whole sequence waiting on an engine that isn't ready.
                    continuation.resume()
                    return
                }

                // An overlapping call takes over, but the previous waiter is
                // released first: leaving a continuation unresumed would hang
                // its caller forever.
                finishCurrent()

                let utterance = makeUtterance(request)
                self.continuation = continuation
                pendingUtterance = utterance
                synthesizer.speak(utterance)
            }
        }
    }

    func stop() {
        queue.async { [self] in
            // Resume and clear first so the `didCancel` callback that
            // `stopSpeaking` triggers finds nothing left to resume.
            finishCurrent()
            if let synthesizer, synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
            }
        }
    }

    // MARK: - Queue-confined helpers

    /// Releases whoever is waiting on the current utterance, if anyone is.
    /// Safe to call repeatedly — the serial queue plus clearing the stored
    /// continuation is what keeps this to one resume per continuation.
    private func finishCurrent() {
        pendingUtterance = nil
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume()
    }

    /// Finishes only if `utterance` is still the one being waited on, so a
    /// callback for an utterance that has already been superseded is ignored.
    private func finish(_ utterance: AVSpeechUtterance) {
        guard pendingUtterance === utterance else { return }
        finishCurrent()
    }

    private func makeUtterance(_ request: SpeechRequest) -> AVSpeechUtterance {
        let utterance: AVSpeechUtterance

        if let ipa = request.ipa {
            let attributed = NSMutableAttributedString(string: request.text)
            attributed.addAttribute(
                NSAttributedString.Key(rawValue: AVSpeechSynthesisIPANotationAttribute),
                value: "/\(ipa)/",
                range: NSRange(location: 0, length: attributed.length)
            )
            utterance = AVSpeechUtterance(attributedString: attributed)
        } else {
            utterance = AVSpeechUtterance(string: request.text)
        }

        utterance.rate = request.rate
        utterance.pitchMultiplier = request.pitchMultiplier
        utterance.volume = request.volume
        utterance.voice = voice
        return utterance
    }
}

extension SpeechEngine: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        queue.async { [self] in finish(utterance) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        queue.async { [self] in finish(utterance) }
    }
}
