import Foundation

/// Result of analyzing a hum: key, tempo and one chord per bar.
struct HumAnalysis {
    var keyName: String
    var isMinorKey: Bool
    var bpm: Int
    var chords: [String]
    var notes: [NoteEvent]
}

/// Turns a transcribed melody into a key, tempo and chord progression.
enum ChordEngine {
    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // Mock build: the results grid always shows five rows of two chords.
    static let progressionLength = 10

    // Krumhansl-Schmuckler key profiles.
    private static let majorProfile: [Double] = [
        6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88
    ]
    private static let minorProfile: [Double] = [
        6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17
    ]

    static func analyze(notes: [NoteEvent], duration: TimeInterval) -> HumAnalysis {
        guard !notes.isEmpty else {
            return HumAnalysis(
                keyName: "Am",
                isMinorKey: true,
                bpm: 96,
                chords: normalizedProgression([], tonic: 9, isMinor: true),
                notes: notes
            )
        }

        var histogram = [Double](repeating: 0, count: 12)
        for note in notes {
            histogram[note.pitch % 12] += note.duration
        }

        let (tonic, isMinor) = estimateKey(histogram: histogram)
        let bpm = estimateBPM(notes: notes)
        var chords = assignChords(
            notes: notes,
            duration: duration,
            tonic: tonic,
            isMinor: isMinor,
            bpm: bpm
        )

        chords = normalizedProgression(chords, tonic: tonic, isMinor: isMinor)

        return HumAnalysis(
            keyName: symbol(root: tonic, minor: isMinor),
            isMinorKey: isMinor,
            bpm: bpm,
            chords: chords,
            notes: notes
        )
    }

    private static func symbol(root: Int, minor: Bool) -> String {
        noteNames[root] + (minor ? "m" : "")
    }

    /// Pads or trims the detected chords to exactly `progressionLength`, cycling a
    /// diatonic filler progression without repeating the same chord back to back.
    private static func normalizedProgression(_ chords: [String], tonic: Int, isMinor: Bool) -> [String] {
        var result = Array(chords.prefix(progressionLength))
        let filler = isMinor
            ? [symbol(root: tonic, minor: true),
               symbol(root: (tonic + 8) % 12, minor: false),
               symbol(root: (tonic + 3) % 12, minor: false),
               symbol(root: (tonic + 10) % 12, minor: false)]
            : [symbol(root: tonic, minor: false),
               symbol(root: (tonic + 7) % 12, minor: false),
               symbol(root: (tonic + 9) % 12, minor: true),
               symbol(root: (tonic + 5) % 12, minor: false)]
        var index = 0
        while result.count < progressionLength {
            let candidate = filler[index % filler.count]
            if result.last != candidate { result.append(candidate) }
            index += 1
        }
        return result
    }

    // MARK: - Key estimation

    private static func estimateKey(histogram: [Double]) -> (tonic: Int, isMinor: Bool) {
        var best = (tonic: 9, isMinor: true, score: -Double.infinity)
        for tonic in 0..<12 {
            var rotated = [Double](repeating: 0, count: 12)
            for pc in 0..<12 {
                rotated[pc] = histogram[(pc + tonic) % 12]
            }
            let majorScore = correlation(rotated, majorProfile)
            let minorScore = correlation(rotated, minorProfile)
            if majorScore > best.score {
                best = (tonic, false, majorScore)
            }
            if minorScore > best.score {
                best = (tonic, true, minorScore)
            }
        }
        return (best.tonic, best.isMinor)
    }

    private static func correlation(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(x.count)
        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n
        var numerator = 0.0
        var denomX = 0.0
        var denomY = 0.0
        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            numerator += dx * dy
            denomX += dx * dx
            denomY += dy * dy
        }
        let denominator = (denomX * denomY).squareRoot()
        return denominator > 0 ? numerator / denominator : 0
    }

    // MARK: - Tempo estimation

    private static func estimateBPM(notes: [NoteEvent]) -> Int {
        let onsets = notes.map(\.start)
        guard onsets.count >= 3 else { return 96 }

        var intervals: [Double] = []
        for i in 1..<onsets.count {
            let interval = onsets[i] - onsets[i - 1]
            if (0.15...2.0).contains(interval) {
                intervals.append(interval)
            }
        }
        guard !intervals.isEmpty else { return 96 }

        let median = intervals.sorted()[intervals.count / 2]
        var bpm = 60.0 / median
        while bpm < 65 { bpm *= 2 }
        while bpm > 160 { bpm /= 2 }
        return Int(bpm.rounded())
    }

    // MARK: - Chord assignment

    private struct Candidate {
        let symbol: String
        let root: Int
        let pitchClasses: Set<Int>
        let prior: Double
    }

    private static func assignChords(
        notes: [NoteEvent],
        duration: TimeInterval,
        tonic: Int,
        isMinor: Bool,
        bpm: Int
    ) -> [String] {
        let barDuration = 4.0 * 60.0 / Double(bpm)
        let barCount = max(1, min(16, Int((duration / barDuration).rounded(.up))))

        // Diatonic triads with mild functional priors (tonic > dominant > ...).
        let degrees: [(offset: Int, minor: Bool, prior: Double)] = isMinor
            ? [(0, true, 1.0), (3, false, 0.85), (5, true, 0.8), (7, true, 0.9), (8, false, 0.88), (10, false, 0.75)]
            : [(0, false, 1.0), (2, true, 0.7), (4, true, 0.65), (5, false, 0.9), (7, false, 0.95), (9, true, 0.85)]

        let candidates: [Candidate] = degrees.map { degree in
            let root = (tonic + degree.offset) % 12
            let third = (root + (degree.minor ? 3 : 4)) % 12
            let fifth = (root + 7) % 12
            return Candidate(
                symbol: symbol(root: root, minor: degree.minor),
                root: root,
                pitchClasses: [root, third, fifth],
                prior: degree.prior
            )
        }

        var chords: [String] = []
        for bar in 0..<barCount {
            let barStart = Double(bar) * barDuration
            let barEnd = barStart + barDuration

            // Weight each pitch class by how long the melody sits on it in this bar.
            var weights = [Double](repeating: 0, count: 12)
            for note in notes {
                let overlap = min(note.start + note.duration, barEnd) - max(note.start, barStart)
                if overlap > 0 {
                    weights[note.pitch % 12] += overlap
                }
            }

            let total = weights.reduce(0, +)
            if total <= 0 {
                chords.append(chords.last ?? candidates[0].symbol)
                continue
            }

            var best: (symbol: String, score: Double) = (candidates[0].symbol, -1)
            for candidate in candidates {
                var score = 0.0
                for pc in candidate.pitchClasses { score += weights[pc] }
                score += weights[candidate.root] * 0.5
                score *= candidate.prior
                if score > best.score {
                    best = (candidate.symbol, score)
                }
            }
            chords.append(best.symbol)
        }
        return chords
    }
}
