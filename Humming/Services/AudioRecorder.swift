import AVFoundation
import SwiftUI

/// Records the user's hum to an AAC file while publishing elapsed time
/// and metered levels for the live waveform.
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    static let barCount = 26
    static let maxDuration: TimeInterval = 60

    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var levels: [CGFloat] = Array(repeating: 0.08, count: AudioRecorder.barCount)
    /// 0...1 smoothed loudness driving the orb pulse.
    @Published private(set) var currentLevel: CGFloat = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private(set) var lastRecordingURL: URL?

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hum-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.record()

        self.recorder = recorder
        lastRecordingURL = url
        elapsed = 0
        levels = Array(repeating: 0.08, count: Self.barCount)
        isRecording = true
        isPaused = false

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Toggles pause/resume while keeping the same recording file.
    func togglePause() {
        guard let recorder else { return }
        if isPaused {
            recorder.record()
            isPaused = false
        } else {
            recorder.pause()
            isPaused = true
            currentLevel = 0
        }
    }

    /// Stops recording and returns the file URL with the captured duration.
    func stop() -> (url: URL, duration: TimeInterval)? {
        guard let recorder else { return nil }
        let duration = recorder.isRecording ? recorder.currentTime : elapsed
        finish(recorder)
        guard let url = lastRecordingURL, duration > 0 else { return nil }
        return (url, duration)
    }

    /// Stops and discards the recording.
    func cancel() {
        guard let recorder else { return }
        finish(recorder)
        recorder.deleteRecording()
        lastRecordingURL = nil
    }

    private func finish(_ recorder: AVAudioRecorder) {
        recorder.stop()
        timer?.invalidate()
        timer = nil
        self.recorder = nil
        isRecording = false
        isPaused = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func tick() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        elapsed = recorder.currentTime

        // averagePower is in dBFS (-160...0); map roughly -50...0 dB to 0...1.
        let power = recorder.averagePower(forChannel: 0)
        let normalized = CGFloat(max(0, min(1, (power + 50) / 50)))

        currentLevel = currentLevel * 0.7 + normalized * 0.3

        var next = levels
        next.removeFirst()
        next.append(0.1 + normalized * 0.9)
        levels = next
    }
}
