import SwiftUI

/// Owns the capture flow: idle "Record a melody" screen → listening →
/// processing → chords-ready results.
struct HomeView: View {
    enum Phase: Equatable {
        case idle
        case recording
        case processing
        case results(Hum)
    }

    @EnvironmentObject private var store: HumStore
    @StateObject private var recorder = AudioRecorder()

    @State private var phase: Phase = .idle
    @State private var showLibrary = false
    @State private var showPermissionAlert = false
    @State private var freshAudioURL: URL?

    var body: some View {
        ZStack {
            switch phase {
            case .idle:
                idleScreen
                    .transition(.opacity)
            case .recording:
                ListeningView(
                    recorder: recorder,
                    onStop: finishRecording,
                    onCancel: cancelRecording
                )
                .transition(.opacity)
            case .processing:
                ProcessingView()
                    .transition(.opacity)
            case .results(let hum):
                if let audioURL = freshAudioURL {
                    ResultsView(
                        hum: hum,
                        audioURL: audioURL,
                        mode: .fresh(
                            onSave: { finalHum in
                                store.add(finalHum, audioSourceURL: audioURL)
                                backToIdle()
                            },
                            onRecordAgain: {
                                discardFreshRecording()
                                backToIdle()
                                startRecording()
                            },
                            onClose: {
                                discardFreshRecording()
                                backToIdle()
                            }
                        )
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: phase)
        .fullScreenCover(isPresented: $showLibrary) {
            LibraryView()
        }
        .alert("Microphone access needed", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable the microphone in Settings so Humming can hear your melody.")
        }
    }

    // MARK: - Idle screen (Figma 19:161 "Record a melody")

    private var idleScreen: some View {
        ZStack {
            HumTheme.charcoal.ignoresSafeArea()

            // Glass slab glowing up from the bottom edge.
            LiquidGlassBlob()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .offset(y: 330)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    greeting
                    Spacer()
                    Button {
                        showLibrary = true
                    } label: {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(HumTheme.mutedOnDark)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Your hums")
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer()
            }

            Text("Tap and start humming")
                .font(.system(size: 16))
                .foregroundStyle(HumTheme.textOnDark)
        }
        .contentShape(Rectangle())
        .onTapGesture { startRecording() }
        .preferredColorScheme(.dark)
    }

    /// Playful greeting from the brand UI COMMS guidelines.
    private var greeting: some View {
        let lines = HumTheme.greetingOfTheDay(humCount: store.hums.count)
        return VStack(alignment: .leading, spacing: 0) {
            Text(lines.top)
                .foregroundStyle(HumTheme.greetingGray)
            Text(lines.bottom)
                .foregroundStyle(.white)
        }
        .font(.system(size: 26, weight: .medium))
        .kerning(-0.3)
    }

    // MARK: - Flow

    private func startRecording() {
        Task {
            guard await recorder.requestPermission() else {
                showPermissionAlert = true
                return
            }
            do {
                try recorder.start()
                phase = .recording
            } catch {
                showPermissionAlert = true
            }
        }
    }

    private func finishRecording() {
        guard let result = recorder.stop() else {
            backToIdle()
            return
        }
        freshAudioURL = result.url
        phase = .processing

        Task.detached(priority: .userInitiated) {
            let notes = (try? PitchTracker.extractNotes(from: result.url)) ?? []
            let analysis = ChordEngine.analyze(notes: notes, duration: result.duration)

            // Keep the "Transcribing melody..." moment readable.
            try? await Task.sleep(for: .seconds(1.4))

            await MainActor.run {
                let hum = Hum(
                    id: UUID(),
                    name: store.nextDefaultName,
                    createdAt: .now,
                    duration: result.duration,
                    key: analysis.keyName,
                    bpm: analysis.bpm,
                    timeSignature: "4/4",
                    chords: analysis.chords,
                    notes: analysis.notes,
                    audioFileName: result.url.lastPathComponent
                )
                phase = .results(hum)
            }
        }
    }

    private func cancelRecording() {
        recorder.cancel()
        backToIdle()
    }

    private func discardFreshRecording() {
        if let url = freshAudioURL {
            try? FileManager.default.removeItem(at: url)
        }
        freshAudioURL = nil
    }

    private func backToIdle() {
        phase = .idle
    }
}

#Preview {
    HomeView()
        .environmentObject(HumStore())
}
