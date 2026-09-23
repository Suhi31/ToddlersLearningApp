//
//  RhymeCues.swift
//  ToddlerLearningApp
//
//  When each lyric line is sung in a rhyme's recording, so the detail screen
//  can highlight the line actually being sung.
//
//  Static content like Rhyme itself, but it lives in a sidecar JSON beside the
//  audio rather than in RhymeContent.swift: a long song carries dozens of
//  cues, it is generated rather than written by hand, and it is only valid for
//  one exact recording — the same reasoning as the Learn Numbers counting
//  timings (see RecordedSpeechService.countingOnsets). Written by
//  tools/gen_rhyme_cues.py; see that script for how the times are found.
//
//  A rhyme with no sidecar simply has no cues, and the detail view falls back
//  to spreading the lines evenly across playback.
//

import Foundation

struct RhymeCues: Sendable {

    /// The moment `line` starts being sung, in seconds into the recording.
    /// A line appears once per time it is sung, so a song that repeats its
    /// verse has several cues for the same line.
    struct Cue: Sendable {
        let time: TimeInterval
        let line: Int
    }

    /// In playback order, which `line(at:)` relies on.
    let cues: [Cue]

    /// Reads the sidecar for a rhyme, or nil when it has none — which is also
    /// what happens for a rhyme with no recording at all, since the generator
    /// only writes one beside an audio file.
    static func load(for rhyme: Rhyme, bundle: Bundle = .main) -> RhymeCues? {
        let name = rhyme.audioFileName as NSString
        guard let url = bundle.url(forResource: name.deletingPathExtension,
                                   withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }

        // [seconds, line index] pairs — compact, since a long song has many.
        let cues = payload.cues.compactMap { pair -> Cue? in
            guard pair.count == 2 else { return nil }
            return Cue(time: pair[0], line: Int(pair[1]))
        }
        return cues.isEmpty ? nil : RhymeCues(cues: cues)
    }

    /// The line being sung at `time`: the last one to have started. Nil before
    /// the first cue, which is the moment or two of music some recordings open
    /// with — nothing is being sung yet, so nothing should light up.
    func line(at time: TimeInterval) -> Int? {
        var low = 0
        var high = cues.count - 1
        var current: Int?
        while low <= high {
            let middle = (low + high) / 2
            if cues[middle].time <= time {
                current = cues[middle].line
                low = middle + 1
            } else {
                high = middle - 1
            }
        }
        return current
    }

    private struct Payload: Decodable {
        let duration: TimeInterval
        let cues: [[Double]]
    }
}
