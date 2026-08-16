import AVFoundation
import Foundation

@MainActor
final class HumPlayer {
    private var engine: AVAudioEngine?
    private var players: [AVAudioPlayerNode] = []

    func play(_ hum: Hum) throws {
        stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        let engine = AVAudioEngine()
        let mixer = engine.mainMixerNode
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

        var nodes: [AVAudioPlayerNode] = []

        func attachSine(hz: Double, start: Double, duration: Double, gain: Float) {
            guard let buffer = Self.sineBuffer(hz: hz, duration: duration, gain: gain, format: format) else { return }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: format)
            nodes.append(player)
            let sampleTime = AVAudioFramePosition(start * format.sampleRate)
            let time = AVAudioTime(sampleTime: sampleTime, atRate: format.sampleRate)
            player.scheduleBuffer(buffer, at: time, options: [])
        }

        for chord in hum.chords {
            let third = chord.quality == .major ? 4.0 : 3.0
            let roots = [48.0 + Double(chord.root), 48 + Double(chord.root) + third, 48 + Double(chord.root) + 7]
            for midi in roots {
                attachSine(
                    hz: Pitch.midiToHz(midi),
                    start: chord.startMs / 1000,
                    duration: max(0.2, chord.durationMs / 1000),
                    gain: 0.08
                )
            }
        }

        for note in hum.notes {
            attachSine(
                hz: Pitch.midiToHz(note.midi),
                start: note.startMs / 1000,
                duration: max(0.08, note.durationMs / 1000),
                gain: 0.18
            )
        }

        try engine.start()
        for player in nodes {
            player.play()
        }

        self.engine = engine
        self.players = nodes
    }

    func stop() {
        players.forEach { $0.stop() }
        players.removeAll()
        engine?.stop()
        engine = nil
    }

    private static func sineBuffer(
        hz: Double,
        duration: Double,
        gain: Float,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(max(1, duration * format.sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        let rate = format.sampleRate
        let channels = Int(format.channelCount)
        for ch in 0..<channels {
            guard let data = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<Int(frames) {
                let t = Double(i) / rate
                let env: Float
                if t < 0.02 {
                    env = Float(t / 0.02)
                } else if t > duration - 0.04 {
                    env = Float(max(0, (duration - t) / 0.04))
                } else {
                    env = 1
                }
                data[i] = Float(sin(2 * Double.pi * hz * t)) * gain * env
            }
        }
        return buffer
    }
}
