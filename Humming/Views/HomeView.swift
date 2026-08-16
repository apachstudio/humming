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
    @State private var isRecordButtonPressed = false
    @State private var isRecordButtonBreathing = false
    @State private var isRecordTransitioning = false
    @Namespace private var recordCircleNamespace

    var body: some View {
        ZStack {
            switch phase {
            case .idle:
                idleScreen
                    .transition(.premiumIdleExit)
            case .recording:
                ListeningView(
                    recorder: recorder,
                    recordCircleNamespace: recordCircleNamespace,
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
        .animation(.spring(response: 0.72, dampingFraction: 0.76), value: phase)
        .fullScreenCover(isPresented: $showLibrary) {
            LibraryView()
        }
        .alert("Microphone access needed", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) {
                Haptics.light()
            }
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
                        Haptics.selection()
                        showLibrary = true
                    } label: {
                        ZStack {
                            DarkGlassCircle(size: 46, showsGlyph: false, showsBloom: false)
                            Image("record-glyph")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 20)
                        }
                    }
                    .accessibilityLabel("Your hums")
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .opacity(isRecordTransitioning ? 0 : 1)
                .offset(y: isRecordTransitioning ? -12 : 0)
                .animation(.easeInOut(duration: 0.5), value: isRecordTransitioning)

                greeting
                    .padding(.top, 56)
                    .opacity(isRecordTransitioning ? 0 : 1)
                    .offset(y: isRecordTransitioning ? -58 : 0)
                    .blur(radius: isRecordTransitioning ? 10 : 0)
                    .animation(.easeInOut(duration: 0.72), value: isRecordTransitioning)

                Spacer()

                DarkGlassCircle(
                    size: 170,
                    bloomOpacity: recordButtonBloomOpacity,
                    bloomScale: recordButtonBloomScale,
                    circleAssetName: "liquid-glass-button"
                )
                .matchedGeometryEffect(
                    id: "record-circle",
                    in: recordCircleNamespace,
                    properties: .frame,
                    anchor: .center
                )
                .scaleEffect(recordButtonScale)
                .animation(.easeInOut(duration: 2.8), value: isRecordButtonBreathing)
                .animation(.spring(response: 0.62, dampingFraction: 0.44), value: isRecordButtonPressed)
                .animation(.easeInOut(duration: 0.76), value: isRecordTransitioning)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isRecordButtonPressed, !isRecordTransitioning else { return }
                            Haptics.medium()
                            withAnimation(.spring(response: 0.58, dampingFraction: 0.45)) {
                                isRecordButtonPressed = true
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.86, dampingFraction: 0.36, blendDuration: 0.12)) {
                                isRecordButtonPressed = false
                            }
                            beginRecordingTransition(playsHaptic: false)
                        }
                )
                .accessibilityLabel("Start recording")
                .accessibilityAddTraits(.isButton)

                Spacer()

                Text("Swipe up or tap to start humming")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HumTheme.labelFaint)
                    .padding(.bottom, 20)
                    .opacity(isRecordTransitioning ? 0 : 1)
                    .offset(y: isRecordTransitioning ? 40 : 0)
                    .blur(radius: isRecordTransitioning ? 5 : 0)
                    .animation(.easeInOut(duration: 0.58), value: isRecordTransitioning)
            }
        }
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .simultaneousGesture(swipeToRecordGesture)
        .accessibilityAction(named: "Start recording") {
            beginRecordingTransition(playsHaptic: true)
        }
        .task { await runRecordButtonBreathing() }
    }

    /// Playful greeting from the brand UI COMMS guidelines.
    private var greeting: some View {
        return VStack(spacing: 0) {
            Text("Hey, Andrea")
                .foregroundStyle(HumTheme.greetingGray)
            Text("Back for another hit?")
                .foregroundStyle(.white)
        }
        .font(.system(size: 32, weight: .medium))
        .kerning(-0.48)
        .multilineTextAlignment(.center)
        .padding(32)
    }

    private var recordButtonScale: CGFloat {
        if isRecordButtonPressed { return 0.91 }
        return isRecordButtonBreathing ? 1.02 : 0.99
    }

    private var recordButtonBloomOpacity: Double {
        if isRecordButtonPressed { return 0.04 }
        if isRecordTransitioning { return 1 }
        return isRecordButtonBreathing ? 1 : 0.5
    }

    private var recordButtonBloomScale: CGFloat {
        if isRecordButtonPressed { return 0.82 }
        if isRecordTransitioning { return 1.18 }
        return isRecordButtonBreathing ? 1.35 : 1
    }

    // MARK: - Flow

    private var swipeToRecordGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let upwardDistance = max(
                    -value.translation.height,
                    -value.predictedEndTranslation.height
                )
                let horizontalDistance = max(
                    abs(value.translation.width),
                    abs(value.predictedEndTranslation.width)
                )

                guard upwardDistance >= 72,
                      upwardDistance > horizontalDistance * 1.15 else {
                    return
                }

                beginRecordingTransition(playsHaptic: true)
            }
    }

    private func beginRecordingTransition(playsHaptic: Bool) {
        guard phase == .idle, !isRecordTransitioning else { return }
        if playsHaptic {
            Haptics.medium()
        }

        withAnimation(.easeInOut(duration: 0.76)) {
            isRecordTransitioning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) {
            startRecording()
        }
    }

    private func startRecording() {
        Task {
            guard await recorder.requestPermission() else {
                isRecordTransitioning = false
                showPermissionAlert = true
                return
            }
            do {
                try recorder.start()
                withAnimation(.spring(response: 0.72, dampingFraction: 0.76)) {
                    phase = .recording
                }
            } catch {
                isRecordTransitioning = false
                showPermissionAlert = true
            }
        }
    }

    private func runRecordButtonBreathing() async {
        isRecordButtonBreathing = false
        isRecordTransitioning = false
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 2.8)) {
                isRecordButtonBreathing = true
            }
            try? await Task.sleep(for: .seconds(2.8))

            withAnimation(.easeInOut(duration: 2.8)) {
                isRecordButtonBreathing = false
            }
            try? await Task.sleep(for: .seconds(2.8))
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

            // Short pause for the prototype processing state.
            try? await Task.sleep(for: .seconds(0.45))

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

private extension AnyTransition {
    static var premiumIdleExit: AnyTransition {
        .opacity
    }
}

#Preview {
    HomeView()
        .environmentObject(HumStore())
}
