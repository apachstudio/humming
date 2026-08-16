import SwiftUI

/// Owns the capture flow: home ("alt 3") → recording → processing →
/// chords-ready results.
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
                    onStop: finishRecording
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

    // MARK: - Home screen (Figma flow 3, "alt 3")

    private var idleScreen: some View {
        ZStack {
            HumTheme.charcoal.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        showLibrary = true
                    } label: {
                        Image(systemName: "archivebox")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(HumTheme.surfaceDark, in: Circle())
                    }
                    .accessibilityLabel("Your hums")
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                greeting
                    .padding(.top, 56)

                Spacer()

                LiquidGlassCircle(size: 150)

                Spacer()

                Text("Tap and start humming")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HumTheme.labelFaint)
                    .padding(.bottom, 20)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { startRecording() }
        .preferredColorScheme(.dark)
    }

    /// Playful greeting from the brand UI COMMS guidelines.
    private var greeting: some View {
        let lines = HumTheme.greetingOfTheDay(humCount: store.hums.count)
        return VStack(spacing: 0) {
            Text(lines.top)
                .foregroundStyle(HumTheme.greetingGray)
            Text(lines.bottom)
                .foregroundStyle(.white)
        }
        .font(.system(size: 32, weight: .medium))
        .kerning(-0.48)
        .multilineTextAlignment(.center)
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
