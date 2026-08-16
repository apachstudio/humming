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
    /// PR #1 descend: the circle travels down this many points, then rises
    /// back as Stop once recording is live. Halo stays on the circle.
    @State private var recordCircleOffset: CGFloat = 0
    @State private var showsStopControl = false

    private static let recordCircleDescend: CGFloat = 132

    var body: some View {
        ZStack {
            switch phase {
            case .idle, .recording:
                captureScreen
                    .transition(.premiumIdleExit)
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

    // MARK: - Shared Home / Recording canvas

    /// One canvas for idle and recording so the circle never unmounts:
    /// press → descend with halo → Recording chrome → slide back up as Stop.
    private var captureScreen: some View {
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
                    .allowsHitTesting(phase == .idle && !isRecordTransitioning)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .opacity(isIdleChromeVisible ? 1 : 0)
                .offset(y: isIdleChromeVisible ? 0 : -12)
                .animation(.easeInOut(duration: 0.5), value: isIdleChromeVisible)

                greeting
                    .padding(.top, 56)
                    .opacity(isIdleChromeVisible ? 1 : 0)
                    .offset(y: isIdleChromeVisible ? 0 : -58)
                    .blur(radius: isIdleChromeVisible ? 0 : 10)
                    .animation(.easeInOut(duration: 0.72), value: isIdleChromeVisible)

                Spacer()

                DarkGlassCircle(
                    size: 170,
                    glyph: showsStopControl ? .stop : .wave,
                    bloomOpacity: recordButtonBloomOpacity,
                    bloomScale: recordButtonBloomScale,
                    circleAssetName: "liquid-glass-button"
                )
                .scaleEffect(recordButtonScale)
                .offset(y: recordCircleOffset)
                .animation(.easeInOut(duration: 2.8), value: isRecordButtonBreathing)
                .animation(.spring(response: 0.62, dampingFraction: 0.44), value: isRecordButtonPressed)
                .animation(.easeOut(duration: 0.15), value: recorder.currentLevel)
                .animation(.easeInOut(duration: 0.3), value: recorder.isPaused)
                .gesture(recordCircleGesture)
                .accessibilityLabel(showsStopControl ? "Stop recording" : "Start recording")
                .accessibilityAddTraits(.isButton)

                Spacer()

                Text("Swipe up or tap to start humming")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HumTheme.labelFaint)
                    .padding(.bottom, 20)
                    .opacity(isIdleChromeVisible ? 1 : 0)
                    .offset(y: isIdleChromeVisible ? 0 : 40)
                    .blur(radius: isIdleChromeVisible ? 0 : 5)
                    .animation(.easeInOut(duration: 0.58), value: isIdleChromeVisible)
            }

            if phase == .recording {
                ListeningView(recorder: recorder, onStop: finishRecording)
                    .transition(.premiumRecordingEnter)
            }
        }
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                guard phase == .recording else { return }
                Haptics.medium()
                finishRecording()
            }
        )
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

    private var isIdleChromeVisible: Bool {
        phase == .idle && !isRecordTransitioning
    }

    private var recordButtonScale: CGFloat {
        if isRecordButtonPressed { return 0.91 }
        if phase == .recording {
            let levelBoost = recorder.isPaused ? 0 : recorder.currentLevel
            return 1 + levelBoost * 0.045
        }
        return isRecordButtonBreathing ? 1.02 : 0.99
    }

    private var recordButtonBloomOpacity: Double {
        if isRecordButtonPressed { return 0.04 }
        if phase == .recording {
            return recorder.isPaused ? 0.38 : 0.82
        }
        // Keep the home halo on the circle as it descends — no fade-out,
        // and no oversized bottom wash to hand off to.
        if isRecordTransitioning { return 1 }
        return isRecordButtonBreathing ? 1 : 0.5
    }

    private var recordButtonBloomScale: CGFloat {
        if isRecordButtonPressed { return 0.82 }
        if phase == .recording {
            let levelBoost = recorder.isPaused ? 0 : recorder.currentLevel
            return (recorder.isPaused ? 0.94 : 1.12) + levelBoost * 0.32
        }
        if isRecordTransitioning { return 1.35 }
        return isRecordButtonBreathing ? 1.35 : 1
    }

    // MARK: - Gestures

    private var recordCircleGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isRecordButtonPressed else { return }
                if phase == .recording {
                    Haptics.medium()
                    withAnimation(.spring(response: 0.58, dampingFraction: 0.45)) {
                        isRecordButtonPressed = true
                    }
                    return
                }
                guard !isRecordTransitioning else { return }
                Haptics.medium()
                withAnimation(.spring(response: 0.58, dampingFraction: 0.45)) {
                    isRecordButtonPressed = true
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.86, dampingFraction: 0.36, blendDuration: 0.12)) {
                    isRecordButtonPressed = false
                }
                if phase == .recording {
                    finishRecording()
                    return
                }
                beginRecordingTransition(playsHaptic: false)
            }
    }

    private var swipeToRecordGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard phase == .idle else { return }
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

    // MARK: - Flow

    private func beginRecordingTransition(playsHaptic: Bool) {
        guard phase == .idle, !isRecordTransitioning else { return }
        if playsHaptic {
            Haptics.medium()
        }

        withAnimation(.easeInOut(duration: 0.76)) {
            isRecordTransitioning = true
            recordCircleOffset = Self.recordCircleDescend
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) {
            startRecording()
        }
    }

    private func startRecording() {
        Task {
            guard await recorder.requestPermission() else {
                resetCaptureCircle()
                showPermissionAlert = true
                return
            }
            do {
                try recorder.start()
                showsStopControl = true
                withAnimation(.spring(response: 0.72, dampingFraction: 0.76)) {
                    phase = .recording
                    recordCircleOffset = 0
                }
            } catch {
                resetCaptureCircle()
                showPermissionAlert = true
            }
        }
    }

    private func runRecordButtonBreathing() async {
        isRecordButtonBreathing = false
        while !Task.isCancelled {
            guard phase == .idle, !isRecordTransitioning else {
                if isRecordButtonBreathing {
                    isRecordButtonBreathing = false
                }
                try? await Task.sleep(for: .milliseconds(200))
                continue
            }
            withAnimation(.easeInOut(duration: 2.8)) {
                isRecordButtonBreathing = true
            }
            try? await Task.sleep(for: .seconds(2.8))

            guard phase == .idle, !isRecordTransitioning else { continue }
            withAnimation(.easeInOut(duration: 2.8)) {
                isRecordButtonBreathing = false
            }
            try? await Task.sleep(for: .seconds(2.8))
        }
    }

    private func finishRecording() {
        guard phase == .recording else { return }
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

    private func resetCaptureCircle() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isRecordTransitioning = false
            recordCircleOffset = 0
            showsStopControl = false
            isRecordButtonPressed = false
        }
    }

    private func backToIdle() {
        resetCaptureCircle()
        phase = .idle
    }
}

private struct PremiumTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: CGFloat
    let blurRadius: CGFloat
    let yOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .blur(radius: blurRadius)
            .offset(y: yOffset)
    }
}

private extension AnyTransition {
    static var premiumIdleExit: AnyTransition {
        .modifier(
            active: PremiumTransitionModifier(opacity: 0, scale: 1.08, blurRadius: 18, yOffset: -24),
            identity: PremiumTransitionModifier(opacity: 1, scale: 1, blurRadius: 0, yOffset: 0)
        )
    }

    static var premiumRecordingEnter: AnyTransition {
        .modifier(
            active: PremiumTransitionModifier(opacity: 0, scale: 0.9, blurRadius: 24, yOffset: 52),
            identity: PremiumTransitionModifier(opacity: 1, scale: 1, blurRadius: 0, yOffset: 0)
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(HumStore())
}
