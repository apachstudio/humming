import AVFoundation
import Foundation

@MainActor
final class HumRecorder {
    private var engine: AVAudioEngine?
    private var startedAt: Date?
    private var timer: Timer?
    private(set) var frames: [PitchFrame] = []

    var onLevel: ((CGFloat) -> Void)?
    var onElapsed: ((TimeInterval) -> Void)?

    func start() throws {
        stopEngine()
        frames = []

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate

        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let data = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            var samples = [Float](repeating: 0, count: count)
            for i in 0..<count { samples[i] = data[i] }

            let hz = Pitch.detect(samples, sampleRate: sampleRate)
            var sum: Float = 0
            for sample in samples { sum += sample * sample }
            let rms = sqrt(sum / Float(max(count, 1)))

            Task { @MainActor in
                guard let self else { return }
                if let hz, let start = self.startedAt {
                    self.frames.append(PitchFrame(timeMs: Date().timeIntervalSince(start) * 1000, hz: hz))
                }
                self.onLevel?(CGFloat(min(1, rms * 8 + 0.08)))
            }
        }

        try engine.start()
        self.engine = engine
        startedAt = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startedAt else { return }
                self.onElapsed?(Date().timeIntervalSince(start))
            }
        }
    }

    func stop() -> (frames: [PitchFrame], durationMs: Double) {
        let duration = (startedAt.map { Date().timeIntervalSince($0) } ?? 0) * 1000
        let captured = frames
        stopEngine()
        return (captured, max(duration, 400))
    }

    private func stopEngine() {
        timer?.invalidate()
        timer = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        startedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
