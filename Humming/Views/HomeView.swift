import SwiftUI

/// Owns the capture flow: home ("alt 3") → recording → processing → results.
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
    @State private var isHeadlineVisible = false
    @State private var isFinishingRecording = false
    @State private var startRecordingTask: Task<Void, Never>?

    private let recordButtonSize: CGFloat = 156

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch phase {
                case .idle:
                    idleScreen
                        .transition(.premiumIdleExit)
                case .recording:
                    ListeningView(
                        recorder: recorder,
                        onStop: finishRecording
                    )
                    .transition(.identity)
                case .processing:
                    ProcessingView()
                        .transition(.premiumProcessingExit)
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
                                    beginRecordingTransition(playsHaptic: false)
                                },
                                onClose: {
                                    discardFreshRecording()
                                    backToIdle()
                                }
                            )
                        )
                        .transition(.premiumResultsReveal)
                    }
                }

                if showsCaptureButton {
                    captureButton(in: proxy.size)
                }

                if showLibrary {
                    LibraryView(onClose: dismissLibrary)
                        .transition(.premiumLibraryScaleReveal)
                        .zIndex(10)
                }
            }
        }
        .animation(HumMotion.phaseChange, value: phase)
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
                    LiquidGlassNavIconButton(
                        systemName: "music.note.list",
                        accessibilityLabel: "Your hums",
                        tone: .dark,
                        action: presentLibrary
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .opacity(isRecordTransitioning ? 0 : 1)
                .offset(y: isRecordTransitioning ? -12 : 0)
                .animation(HumMotion.libraryExit, value: isRecordTransitioning)

                greeting
                    .padding(.top, 56)
                    .opacity(headlineOpacity)
                    .offset(y: headlineYOffset)
                    .blur(radius: headlineBlurRadius)
                    .animation(HumMotion.headlineExit, value: isRecordTransitioning)
                    .animation(HumMotion.headlineEntrance, value: isHeadlineVisible)

                Spacer()

                Color.clear
                    .frame(width: recordButtonSize, height: recordButtonSize)
                    .accessibilityHidden(true)

                Spacer()

                Text("Tap and start humming")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HumTheme.labelFaint)
                    .padding(.bottom, 20)
                    .opacity(isRecordTransitioning ? 0 : 1)
                    .offset(y: isRecordTransitioning ? 40 : 0)
                    .blur(radius: isRecordTransitioning ? 5 : 0)
                    .animation(HumMotion.bottomHintExit, value: isRecordTransitioning)
            }
        }
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .accessibilityAction(named: "Start recording") {
            beginRecordingTransition(playsHaptic: true)
        }
        .onAppear(perform: runHeadlineEntrance)
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

    private var showsCaptureButton: Bool {
        phase == .idle
    }

    private var isRecordingPhase: Bool {
        if case .recording = phase { return true }
        return false
    }

    @ViewBuilder
    private func captureButton(in screenSize: CGSize) -> some View {
        Button {
            handleRecordButtonTap()
        } label: {
            DarkGlassCircle(
                size: recordButtonSize,
                showsGlyph: false,
                bloomOpacity: recordButtonBloomOpacity,
                bloomScale: recordButtonBloomScale,
                circleAssetName: "liquid-glass-button"
            )
            .overlay {
                Image("record-wave")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(HumTheme.glyphInk.opacity(0.54))
                    .frame(width: recordButtonSize * 0.36, height: recordButtonSize * 0.31)
            }
            .frame(width: recordButtonSize, height: recordButtonSize)
            .contentShape(Circle())
            .scaleEffect(recordButtonScale)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start recording")
        .position(captureButtonPosition(in: screenSize))
        .animation(HumMotion.buttonBreathing, value: isRecordButtonBreathing)
        .animation(HumMotion.buttonPress, value: isRecordButtonPressed)
        .animation(HumMotion.buttonDescend, value: isRecordTransitioning)
        .simultaneousGesture(recordButtonPressGesture)
    }

    private var headlineOpacity: Double {
        if isRecordTransitioning { return 0 }
        return isHeadlineVisible ? 1 : 0
    }

    private var headlineYOffset: CGFloat {
        if isRecordTransitioning { return -58 }
        return isHeadlineVisible ? 0 : 24
    }

    private var headlineBlurRadius: CGFloat {
        if isRecordTransitioning { return 10 }
        return isHeadlineVisible ? 0 : 8
    }

    private var recordButtonScale: CGFloat {
        if isRecordButtonPressed { return 0.91 }
        return isRecordButtonBreathing ? 1.035 : 0.99
    }

    private var recordButtonBloomOpacity: Double {
        if isRecordButtonPressed { return 0.04 }
        if isRecordTransitioning { return 1 }
        return isRecordButtonBreathing ? 1 : 0.5
    }

    private var recordButtonBloomScale: CGFloat {
        if isRecordButtonPressed { return 0.82 }
        if isRecordTransitioning { return 1.35 }
        return isRecordButtonBreathing ? 1.72 : 1.18
    }

    private var captureButtonBloomOpacity: Double {
        recorder.isPaused ? 0.42 : 0.84
    }

    private func captureButtonPosition(in size: CGSize) -> CGPoint {
        let homeY = size.height * 0.65
        let exitY = size.height + recordButtonSize
        let y: CGFloat

        if isRecordTransitioning {
            y = exitY
        } else {
            y = homeY
        }

        return CGPoint(x: size.width / 2, y: y)
    }

    // MARK: - Flow

    private func runHeadlineEntrance() {
        isHeadlineVisible = false
        withAnimation(HumMotion.headlineEntrance) {
            isHeadlineVisible = true
        }
    }

    private var recordButtonPressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isRecordingPhase,
                      !isRecordButtonPressed,
                      !isRecordTransitioning else { return }

                Haptics.medium()
                withAnimation(HumMotion.buttonPress) {
                    isRecordButtonPressed = true
                }
            }
            .onEnded { _ in
                guard !isRecordingPhase else { return }
                withAnimation(HumMotion.buttonRelease) {
                    isRecordButtonPressed = false
                }
            }
    }

    private func handleRecordButtonTap() {
        guard !isRecordingPhase else { return }
        beginRecordingTransition(playsHaptic: false)
    }

    private func presentLibrary() {
        guard !showLibrary else { return }
        Haptics.selection()
        withAnimation(HumMotion.librarySlide) {
            showLibrary = true
        }
    }

    private func dismissLibrary() {
        withAnimation(HumMotion.librarySlide) {
            showLibrary = false
        }
    }

    private func beginRecordingTransition(playsHaptic: Bool) {
        guard phase == .idle, !isRecordTransitioning else { return }
        if playsHaptic {
            Haptics.medium()
        }

        startRecordingTask?.cancel()
        isFinishingRecording = false

        withAnimation(HumMotion.headlineExit) {
            isRecordTransitioning = true
        }

        startRecordingTask = Task {
            try? await Task.sleep(for: HumMotion.startDelay)
            guard !Task.isCancelled else { return }
            await startRecording()
        }
    }

    private func startRecording() async {
        guard !Task.isCancelled else { return }
        guard await recorder.requestPermission() else {
            isRecordTransitioning = false
            showPermissionAlert = true
            return
        }
        guard !Task.isCancelled else { return }

        do {
            try recorder.start()
            withAnimation(HumMotion.phaseChange) {
                phase = .recording
            }
        } catch {
            isRecordTransitioning = false
            showPermissionAlert = true
        }
    }

    private func runRecordButtonBreathing() async {
        isRecordButtonBreathing = false
        while !Task.isCancelled {
            withAnimation(HumMotion.buttonBreathing) {
                isRecordButtonBreathing = true
            }
            try? await Task.sleep(for: .seconds(2.05))

            withAnimation(HumMotion.buttonBreathing) {
                isRecordButtonBreathing = false
            }
            try? await Task.sleep(for: .seconds(2.05))
        }
    }


    private func finishRecording() {
        guard phase == .recording, !isFinishingRecording else { return }
        isFinishingRecording = true
        startRecordingTask?.cancel()

        guard let result = recorder.stop() else {
            backToIdle()
            return
        }
        freshAudioURL = result.url
        withAnimation(HumMotion.phaseChange) {
            phase = .processing
        }

        Task.detached(priority: .userInitiated) {
            let notes = (try? PitchTracker.extractNotes(from: result.url)) ?? []
            let analysis = ChordEngine.analyze(notes: notes, duration: result.duration)

            // Hold the processing state long enough for the reveal to feel deliberate.
            try? await Task.sleep(for: .seconds(0.9))

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
                isRecordTransitioning = false
                isFinishingRecording = false
                withAnimation(.easeInOut(duration: 1.05)) {
                    phase = .results(hum)
                }
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
        startRecordingTask?.cancel()
        startRecordingTask = nil
        isFinishingRecording = false
        isRecordTransitioning = false
        phase = .idle
    }
}


private extension AnyTransition {
    static var premiumIdleExit: AnyTransition {
        .identity
    }

    static var premiumLibraryScaleReveal: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: PremiumLibraryMotionModifier(opacity: 0, scale: 0, cornerRadius: 60),
                identity: PremiumLibraryMotionModifier(opacity: 1, scale: 1, cornerRadius: 0)
            ),
            removal: .modifier(
                active: PremiumLibraryMotionModifier(opacity: 0, scale: 0, cornerRadius: 60),
                identity: PremiumLibraryMotionModifier(opacity: 1, scale: 1, cornerRadius: 0)
            )
        )
    }

    static var premiumProcessingExit: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: PremiumPhaseModifier(opacity: 0, scale: 0.985, yOffset: 12, blur: 18),
                identity: PremiumPhaseModifier(opacity: 1, scale: 1, yOffset: 0, blur: 0)
            ),
            removal: .modifier(
                active: PremiumPhaseModifier(opacity: 0, scale: 1.035, yOffset: -16, blur: 26),
                identity: PremiumPhaseModifier(opacity: 1, scale: 1, yOffset: 0, blur: 0)
            )
        )
    }

    static var premiumResultsReveal: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: PremiumPhaseModifier(opacity: 0, scale: 0.965, yOffset: 34, blur: 26),
                identity: PremiumPhaseModifier(opacity: 1, scale: 1, yOffset: 0, blur: 0)
            ),
            removal: .modifier(
                active: PremiumPhaseModifier(opacity: 0, scale: 0.985, yOffset: 14, blur: 18),
                identity: PremiumPhaseModifier(opacity: 1, scale: 1, yOffset: 0, blur: 0)
            )
        )
    }
}

private struct PremiumPhaseModifier: ViewModifier {
    var opacity: Double
    var scale: CGFloat
    var yOffset: CGFloat
    var blur: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(y: yOffset)
            .blur(radius: blur)
    }
}

private struct PremiumLibraryMotionModifier: AnimatableModifier {
    var opacity: Double
    var scale: CGFloat
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<Double, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(opacity, AnimatablePair(scale, cornerRadius))
        }
        set {
            opacity = newValue.first
            scale = newValue.second.first
            cornerRadius = newValue.second.second
        }
    }

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale, anchor: .topTrailing)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .compositingGroup()
    }
}

#Preview {
    HomeView()
        .environmentObject(HumStore())
}
