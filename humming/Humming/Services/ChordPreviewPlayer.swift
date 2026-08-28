import AVFoundation
import Foundation

@MainActor
final class ChordPreviewPlayer: ObservableObject {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var frequencies: [Double] = []
    private var phases: [Double] = []
    private var amplitude: Double = 0
    private var frameIndex: Double = 0

    func play(chord: String) {
        frequencies = Self.frequencies(for: chord)
        phases = Array(repeating: 0, count: frequencies.count)
        amplitude = 0.22
        frameIndex = 0

        if sourceNode == nil {
            configureEngine()
        }

        if !engine.isRunning {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            try? engine.start()
        }
    }

    func stop() {
        engine.stop()
        amplitude = 0
    }

    private func configureEngine() {
        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                let envelope = min(1, self.frameIndex / (sampleRate * 0.025)) * exp(-self.frameIndex / (sampleRate * 0.72))
                var sample = 0.0

                for index in self.frequencies.indices {
                    sample += sin(self.phases[index]) / Double(max(1, self.frequencies.count))
                    self.phases[index] += 2 * .pi * self.frequencies[index] / sampleRate
                    if self.phases[index] > 2 * .pi {
                        self.phases[index] -= 2 * .pi
                    }
                }

                let value = Float(sample * self.amplitude * envelope)
                for buffer in buffers {
                    guard let pointer = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    pointer[frame] = value
                }

                self.frameIndex += 1
            }

            if self.frameIndex > sampleRate * 1.05 {
                self.amplitude = 0
            }

            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node
    }

    private static func frequencies(for chord: String) -> [Double] {
        let parsed = parse(chord)
        let intervals = parsed.isMinor ? [0, 3, 7, 12] : [0, 4, 7, 12]
        let midiRoot = 48 + parsed.pitchClass
        return intervals.map { midiToFrequency(midiRoot + $0) }
    }

    private static func parse(_ chord: String) -> (pitchClass: Int, isMinor: Bool) {
        let characters = Array(chord)
        let root: String
        if characters.count > 1, characters[1] == "#" || characters[1] == "b" {
            root = String(chord.prefix(2))
        } else {
            root = String(chord.prefix(1))
        }
        return (pitchClass(for: root), chord.hasSuffix("m"))
    }

    private static func pitchClass(for root: String) -> Int {
        switch root {
        case "C": return 0
        case "C#", "Db": return 1
        case "D": return 2
        case "D#", "Eb": return 3
        case "E": return 4
        case "F": return 5
        case "F#", "Gb": return 6
        case "G": return 7
        case "G#", "Ab": return 8
        case "A": return 9
        case "A#", "Bb": return 10
        case "B": return 11
        default: return 0
        }
    }

    private static func midiToFrequency(_ midi: Int) -> Double {
        440 * pow(2, (Double(midi) - 69) / 12)
    }
}
