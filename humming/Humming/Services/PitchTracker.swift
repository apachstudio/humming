import AVFoundation

/// Offline monophonic pitch tracking (YIN) that turns a recorded hum
/// into a sequence of note events.
enum PitchTracker {
    private struct PitchFrame {
        let time: Double
        let frequency: Double
    }

    /// Reads the audio file, tracks the fundamental frequency and
    /// segments it into notes.
    static func extractNotes(from url: URL) throws -> [NoteEvent] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return []
        }
        try file.read(into: buffer)
        guard let channelData = buffer.floatChannelData else { return [] }

        // Mix down to mono.
        let channels = Int(format.channelCount)
        let sampleCount = Int(buffer.frameLength)
        guard sampleCount > 0 else { return [] }
        var mono = [Float](repeating: 0, count: sampleCount)
        for channel in 0..<channels {
            let pointer = channelData[channel]
            for i in 0..<sampleCount { mono[i] += pointer[i] }
        }
        if channels > 1 {
            let scale = 1 / Float(channels)
            for i in 0..<sampleCount { mono[i] *= scale }
        }

        // Decimate to ~11 kHz; humming lives well below 1 kHz.
        let decimation = max(1, Int(format.sampleRate / 11_025))
        var samples = [Float]()
        samples.reserveCapacity(sampleCount / decimation + 1)
        var i = 0
        while i < sampleCount {
            samples.append(mono[i])
            i += decimation
        }
        let sampleRate = format.sampleRate / Double(decimation)

        return segmentNotes(from: pitchFrames(samples: samples, sampleRate: sampleRate))
    }

    // MARK: - YIN pitch detection

    private static func pitchFrames(samples: [Float], sampleRate: Double) -> [PitchFrame] {
        let frameSize = 1024
        let hop = 512
        let minFrequency = 70.0
        let maxFrequency = 800.0
        let tauMin = max(2, Int(sampleRate / maxFrequency))
        let tauMax = min(frameSize / 2, Int(sampleRate / minFrequency))
        guard samples.count >= frameSize, tauMax > tauMin else { return [] }

        var frames: [PitchFrame] = []
        var start = 0
        let windowLength = frameSize - tauMax

        while start + frameSize <= samples.count {
            let time = Double(start) / sampleRate
            let frame = Array(samples[start ..< start + frameSize])

            var rms: Float = 0
            for sample in frame { rms += sample * sample }
            rms = (rms / Float(frameSize)).squareRoot()

            guard rms > 0.01 else {
                frames.append(PitchFrame(time: time, frequency: 0))
                start += hop
                continue
            }

            // Difference function.
            var difference = [Float](repeating: 0, count: tauMax + 1)
            for tau in 1...tauMax {
                var sum: Float = 0
                for j in 0..<windowLength {
                    let delta = frame[j] - frame[j + tau]
                    sum += delta * delta
                }
                difference[tau] = sum
            }

            // Cumulative mean normalized difference.
            var cmndf = [Float](repeating: 1, count: tauMax + 1)
            var runningSum: Float = 0
            for tau in 1...tauMax {
                runningSum += difference[tau]
                cmndf[tau] = runningSum > 0 ? difference[tau] * Float(tau) / runningSum : 1
            }

            // Absolute-threshold pick with local minimum descent.
            var bestTau = 0
            let threshold: Float = 0.15
            var tau = tauMin
            while tau <= tauMax {
                if cmndf[tau] < threshold {
                    while tau + 1 <= tauMax && cmndf[tau + 1] < cmndf[tau] { tau += 1 }
                    bestTau = tau
                    break
                }
                tau += 1
            }
            if bestTau == 0 {
                var minValue = Float.greatestFiniteMagnitude
                var minTau = 0
                for candidate in tauMin...tauMax where cmndf[candidate] < minValue {
                    minValue = cmndf[candidate]
                    minTau = candidate
                }
                if minValue < 0.3 { bestTau = minTau }
            }

            if bestTau > 0 {
                // Parabolic interpolation for sub-sample accuracy.
                var refinedTau = Double(bestTau)
                if bestTau > tauMin && bestTau < tauMax {
                    let s0 = Double(cmndf[bestTau - 1])
                    let s1 = Double(cmndf[bestTau])
                    let s2 = Double(cmndf[bestTau + 1])
                    let denominator = 2 * (2 * s1 - s2 - s0)
                    if abs(denominator) > 1e-12 {
                        refinedTau += (s2 - s0) / denominator
                    }
                }
                frames.append(PitchFrame(time: time, frequency: sampleRate / refinedTau))
            } else {
                frames.append(PitchFrame(time: time, frequency: 0))
            }
            start += hop
        }
        return frames
    }

    // MARK: - Note segmentation

    private static func segmentNotes(from frames: [PitchFrame]) -> [NoteEvent] {
        guard !frames.isEmpty else { return [] }
        let hopTime = frames.count > 1 ? frames[1].time - frames[0].time : 0.046

        var midiPerFrame: [Int?] = frames.map { frame in
            guard frame.frequency > 0 else { return nil }
            let midi = 69 + 12 * log2(frame.frequency / 440)
            let rounded = Int(midi.rounded())
            return (30...90).contains(rounded) ? rounded : nil
        }

        // Remove single-frame glitches between two identical neighbors.
        if midiPerFrame.count >= 3 {
            for index in 1..<(midiPerFrame.count - 1) {
                if let previous = midiPerFrame[index - 1],
                   let next = midiPerFrame[index + 1],
                   previous == next,
                   midiPerFrame[index] != previous {
                    midiPerFrame[index] = previous
                }
            }
        }

        var events: [NoteEvent] = []
        var currentPitch: Int?
        var noteStart: Double = 0
        let minimumDuration = 0.09

        func flush(endTime: Double) {
            guard let pitch = currentPitch else { return }
            let duration = endTime - noteStart
            if duration >= minimumDuration {
                events.append(NoteEvent(pitch: pitch, start: noteStart, duration: duration))
            }
        }

        for (index, midi) in midiPerFrame.enumerated() {
            let time = frames[index].time
            if midi != currentPitch {
                flush(endTime: time)
                currentPitch = midi
                noteStart = time
            }
        }
        flush(endTime: (frames.last?.time ?? 0) + hopTime)
        return events
    }
}
