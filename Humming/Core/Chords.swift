import Foundation

public enum Chords {
    private static let pcNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private static let majorProfile: [Double] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    private static let minorProfile: [Double] = [6.33, 2.68, 3.52, 5.38, 2.6, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    private static let majorDegrees: [(Int, ChordQuality)] = [
        (0, .major), (2, .minor), (4, .minor), (5, .major), (7, .major), (9, .minor),
    ]
    private static let minorDegrees: [(Int, ChordQuality)] = [
        (0, .minor), (3, .major), (5, .minor), (7, .minor), (8, .major), (10, .major),
    ]

    public static func pitchClassName(_ pc: Int) -> String {
        pcNames[((pc % 12) + 12) % 12]
    }

    public static func chordSymbol(root: Int, quality: ChordQuality) -> String {
        let name = pitchClassName(root)
        return quality == .minor ? "\(name)m" : name
    }

    public static func formatKey(tonic: Int, mode: MusicalMode) -> String {
        let name = pitchClassName(tonic)
        return mode == .minor ? "\(name) minor" : "\(name) major"
    }

    private static func pitchClass(_ midi: Double) -> Int {
        ((Int(midi.rounded()) % 12) + 12) % 12
    }

    private static func correlate(histo: [Double], profile: [Double], tonic: Int) -> Double {
        var sum = 0.0
        for i in 0..<12 {
            sum += histo[i] * profile[(i - tonic + 12) % 12]
        }
        return sum
    }

    public static func estimateKey(_ notes: [NoteEvent]) -> EstimatedKey {
        var histo = [Double](repeating: 0, count: 12)
        for note in notes {
            histo[pitchClass(note.midi)] += max(note.durationMs, 1)
        }

        var best = EstimatedKey(tonic: 0, mode: .major)
        var bestScore = -Double.infinity
        for tonic in 0..<12 {
            let major = correlate(histo: histo, profile: majorProfile, tonic: tonic)
            let minor = correlate(histo: histo, profile: minorProfile, tonic: tonic)
            if major > bestScore {
                best = EstimatedKey(tonic: tonic, mode: .major)
                bestScore = major
            }
            if minor > bestScore {
                best = EstimatedKey(tonic: tonic, mode: .minor)
                bestScore = minor
            }
        }
        return best
    }

    public static func estimateTempo(_ notes: [NoteEvent]) -> Int {
        guard notes.count >= 2 else { return 96 }
        var iois: [Double] = []
        for i in 1..<notes.count {
            let gap = notes[i].startMs - notes[i - 1].startMs
            if gap > 120, gap < 1400 { iois.append(gap) }
        }
        guard !iois.isEmpty else { return 96 }
        iois.sort()
        let median = iois[iois.count / 2]
        var bpm = 60_000 / median
        while bpm < 70 { bpm *= 2 }
        while bpm > 160 { bpm /= 2 }
        return Int(bpm.rounded())
    }

    private static func triadPitchClasses(root: Int, quality: ChordQuality) -> Set<Int> {
        let third = quality == .major ? 4 : 3
        return [root, (root + third) % 12, (root + 7) % 12]
    }

    private static func scoreChord(
        notes: [NoteEvent],
        startMs: Double,
        endMs: Double,
        root: Int,
        quality: ChordQuality
    ) -> Double {
        let tones = triadPitchClasses(root: root, quality: quality)
        var score = 0.0
        for note in notes {
            let noteEnd = note.startMs + note.durationMs
            let overlap = min(endMs, noteEnd) - max(startMs, note.startMs)
            guard overlap > 0 else { continue }
            let pc = pitchClass(note.midi)
            if pc == root {
                score += overlap * 3
            } else if tones.contains(pc) {
                score += overlap * 2
            } else {
                score -= overlap * 0.35
            }
        }
        return score
    }

    public static func detectChords(
        notes: [NoteEvent],
        key: EstimatedKey,
        tempo: Int,
        durationMs: Double
    ) -> [ChordEvent] {
        let degrees = key.mode == .minor ? minorDegrees : majorDegrees
        let windowMs = max(750, (60_000 / Double(tempo)) * 2)
        var chords: [ChordEvent] = []

        var start = 0.0
        while start < durationMs {
            let end = min(durationMs, start + windowMs)
            var bestRoot = key.tonic
            var bestQuality: ChordQuality = key.mode == .minor ? .minor : .major
            var bestScore = -Double.infinity

            for (degree, quality) in degrees {
                let root = (key.tonic + degree) % 12
                let score = scoreChord(notes: notes, startMs: start, endMs: end, root: root, quality: quality)
                if score > bestScore {
                    bestRoot = root
                    bestQuality = quality
                    bestScore = score
                }
            }

            if bestScore <= 0 {
                bestRoot = key.tonic
                bestQuality = key.mode == .minor ? .minor : .major
            }

            if let last = chords.last, last.root == bestRoot, last.quality == bestQuality {
                chords[chords.count - 1].durationMs = end - last.startMs
            } else {
                chords.append(
                    ChordEvent(
                        symbol: chordSymbol(root: bestRoot, quality: bestQuality),
                        root: bestRoot,
                        quality: bestQuality,
                        startMs: start,
                        durationMs: end - start
                    )
                )
            }
            start += windowMs
        }

        if chords.isEmpty {
            let quality: ChordQuality = key.mode == .minor ? .minor : .major
            return [
                ChordEvent(
                    symbol: chordSymbol(root: key.tonic, quality: quality),
                    root: key.tonic,
                    quality: quality,
                    startMs: 0,
                    durationMs: durationMs
                ),
            ]
        }
        return chords
    }

    public static func framesToNotes(_ frames: [PitchFrame]) -> [NoteEvent] {
        let voiced = frames.filter { $0.hz > 0 }
        guard let first = voiced.first else { return [] }

        var notes: [NoteEvent] = []
        var currentMidi = Pitch.hzToMidi(first.hz).rounded()
        var startMs = first.timeMs
        var lastMs = startMs

        func flush(_ endMs: Double) {
            let durationMs = endMs - startMs
            if durationMs >= 80 {
                notes.append(NoteEvent(midi: currentMidi, startMs: startMs, durationMs: durationMs))
            }
        }

        for frame in voiced.dropFirst() {
            let midi = Pitch.hzToMidi(frame.hz)
            let rounded = midi.rounded()
            lastMs = frame.timeMs
            if abs(midi - currentMidi) >= 0.6, rounded != currentMidi {
                flush(frame.timeMs)
                currentMidi = rounded
                startMs = frame.timeMs
            }
        }
        flush(lastMs + 90)
        return notes
    }

    public static func analyze(frames: [PitchFrame], durationMs: Double) -> Analysis? {
        let notes = framesToNotes(frames)
        guard !notes.isEmpty else { return nil }
        let key = estimateKey(notes)
        let tempo = estimateTempo(notes)
        let chords = detectChords(notes: notes, key: key, tempo: tempo, durationMs: durationMs)
        return Analysis(
            notes: notes,
            chords: chords,
            key: formatKey(tonic: key.tonic, mode: key.mode),
            tempo: tempo,
            durationMs: durationMs
        )
    }

    /// Hummed-style Am–F–C–G phrase for the simulator / sample path.
    public static func sampleMelody() -> (frames: [PitchFrame], durationMs: Double) {
        let phrase: [(midi: Double, start: Double, duration: Double)] = [
            (69, 0, 620), (72, 620, 360), (76, 980, 420), (69, 1400, 520),
            (65, 2000, 640), (69, 2640, 360), (65, 3000, 420), (60, 3520, 700),
            (64, 4220, 380), (67, 4600, 520), (67, 5240, 480), (71, 5720, 360),
            (74, 6080, 400), (69, 6480, 900),
        ]
        var frames: [PitchFrame] = []
        for note in phrase {
            var t = 0.0
            while t < note.duration {
                let wobble = 1 + 0.008 * sin((t / 70) * Double.pi)
                frames.append(
                    PitchFrame(timeMs: note.start + t, hz: Pitch.midiToHz(note.midi) * wobble)
                )
                t += 40
            }
        }
        return (frames, 7480)
    }
}
