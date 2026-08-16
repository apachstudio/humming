import AVFoundation
import CoreGraphics
import Foundation
import Observation

enum Route: Hashable {
    case results(Hum)
    case library
    case detail(UUID)
}

@Observable
@MainActor
final class AppModel {
    var path: [Route] = []
    var showSplash = true
    var isRecording = false
    var isProcessing = false
    var elapsed: TimeInterval = 0
    var levels: [CGFloat] = Array(repeating: 0.12, count: 48)
    var library: [Hum] = LibraryStore.load()
    var errorMessage: String?
    var savedIDs: Set<UUID> = []

    @ObservationIgnored private let recorder = HumRecorder()
    @ObservationIgnored private let player = HumPlayer()

    init() {
        recorder.onLevel = { [weak self] level in
            guard let self else { return }
            var next = self.levels
            if !next.isEmpty { next.removeFirst() }
            next.append(level)
            self.levels = next
        }
        recorder.onElapsed = { [weak self] value in
            self?.elapsed = value
        }
        savedIDs = Set(library.map(\.id))
    }

    func dismissSplash() {
        showSplash = false
    }

    func startRecording() {
        errorMessage = nil
        elapsed = 0
        levels = Array(repeating: 0.12, count: 48)
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard granted else {
                    self.errorMessage = "Microphone access is needed to hum. You can still try a sample melody."
                    return
                }
                do {
                    try self.recorder.start()
                    self.isRecording = true
                } catch {
                    self.errorMessage = "Couldn't start the microphone. Check Settings → humming."
                }
            }
        }
    }

    func stopRecording() {
        let capture = recorder.stop()
        isRecording = false
        process(frames: capture.frames, durationMs: capture.durationMs)
    }

    func runSample() {
        errorMessage = nil
        let sample = Chords.sampleMelody()
        process(frames: sample.frames, durationMs: sample.durationMs)
    }

    func process(frames: [PitchFrame], durationMs: Double) {
        isProcessing = true
        Task {
            try? await Task.sleep(for: .milliseconds(1800))
            guard let analysis = Chords.analyze(frames: frames, durationMs: durationMs) else {
                isProcessing = false
                errorMessage = "Couldn't hear a melody. Try humming a little louder and longer."
                return
            }
            let hum = Hum(
                title: Titles.title(for: Date(), existing: library.map(\.title)),
                durationMs: analysis.durationMs,
                key: analysis.key,
                tempo: analysis.tempo,
                notes: analysis.notes,
                chords: analysis.chords
            )
            isProcessing = false
            path.append(.results(hum))
        }
    }

    func play(_ hum: Hum) {
        try? player.play(hum)
    }

    func stopPlayback() {
        player.stop()
    }

    func save(_ hum: Hum) {
        library = [hum] + library.filter { $0.id != hum.id }
        savedIDs.insert(hum.id)
        LibraryStore.save(library)
    }

    func delete(id: UUID) {
        library.removeAll { $0.id == id }
        savedIDs.remove(id)
        LibraryStore.save(library)
        path.removeAll { $0 == .detail(id) }
    }

    func hum(id: UUID) -> Hum? {
        library.first { $0.id == id }
    }
}
