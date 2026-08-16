import Foundation

public enum Pitch {
    public static let minHz: Double = 70
    public static let maxHz: Double = 900

    public static func hzToMidi(_ hz: Double) -> Double {
        69 + 12 * log2(hz / 440)
    }

    public static func midiToHz(_ midi: Double) -> Double {
        440 * pow(2, (midi - 69) / 12)
    }

    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    public static func midiToNoteName(_ midi: Double) -> String {
        let rounded = Int(midi.rounded())
        let name = noteNames[((rounded % 12) + 12) % 12]
        let octave = Int(floor(Double(rounded) / 12.0)) - 1
        return "\(name)\(octave)"
    }

    public static func sineWave(hz: Double, sampleRate: Double, seconds: Double, amplitude: Float = 0.6) -> [Float] {
        let n = Int(sampleRate * seconds)
        return (0..<n).map { i in
            Float(sin(2 * Double.pi * hz * Double(i) / sampleRate)) * amplitude
        }
    }

    /// YIN pitch detection. Returns Hz, or nil if unvoiced / out of humming range.
    public static func detect(_ buffer: [Float], sampleRate: Double, threshold: Float = 0.15) -> Double? {
        let half = buffer.count / 2
        guard half >= 32 else { return nil }

        var yin = [Float](repeating: 0, count: half)
        for tau in 1..<half {
            var sum: Float = 0
            for i in 0..<half {
                let delta = buffer[i] - buffer[i + tau]
                sum += delta * delta
            }
            yin[tau] = sum
        }

        yin[0] = 1
        var running: Float = 0
        for tau in 1..<half {
            running += yin[tau]
            yin[tau] = running == 0 ? 1 : (yin[tau] * Float(tau)) / running
        }

        let minTau = max(2, Int(sampleRate / maxHz))
        let maxTau = min(half - 1, Int(sampleRate / minHz))

        var tau = minTau
        while tau <= maxTau {
            if yin[tau] < threshold {
                while tau + 1 <= maxTau, yin[tau + 1] < yin[tau] {
                    tau += 1
                }
                break
            }
            tau += 1
        }

        guard tau <= maxTau, yin[tau] < threshold else { return nil }

        let prev = tau > 0 ? yin[tau - 1] : 1
        let next = tau + 1 < yin.count ? yin[tau + 1] : 1
        let denom = 2 * (2 * yin[tau] - prev - next)
        let shift = denom == 0 ? 0 : Double((prev - next) / denom)
        let freq = sampleRate / (Double(tau) + shift)
        guard freq.isFinite, freq >= minHz, freq <= maxHz else { return nil }
        return freq
    }
}
