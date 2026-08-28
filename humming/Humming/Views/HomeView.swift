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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var isDismissingRecording = false
    @State private var startRecordingTask: Task<Void, Never>?
    @State private var isPreparingLibraryPresentation = false
    @State private var libraryPresentationTask: Task<Void, Never>?

    private let recordButtonSize: CGFloat = 156

    private enum BreathingMotion {
        static let travel = Animation.easeInOut(duration: 1.6)
        static let travelDuration: Duration = .milliseconds(1600)
        static let topHold: Duration = .milliseconds(500)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
            ZStack {
                switch phase {
                case .idle:
                    idleScreen
                        .transition(.premiumIdleExit)
                case .recording:
                    ListeningView(
                        recorder: recorder,
                        isFinishing: isFinishingRecording,
                        isDismissing: isDismissingRecording,
                        onStop: finishRecording,
                        onRestart: restartRecording,
                        onCancel: cancelRecording
                    )
                    .transition(.identity)
                case .processing:
                    ProcessingView()
                        .transition(.identity)
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
                            ),
                            entrySource: .processing
                        )
                        .transition(.premiumResultsReveal)
                    }
                }

                if showsCaptureButton {
                    captureButton(in: proxy.size)
                }

            }
            }
            .toolbar {
                if phase == .idle && !isRecordTransitioning && !isPreparingLibraryPresentation && !showLibrary {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            presentLibrary()
                        } label: {
                            Image("library-icon")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 19, height: 19)
                        }
                        .accessibilityLabel("Your hums")
                    }
                }
            }
            .tint(Color.white.opacity(0.86))
            .toolbar(hidesNavigationBar ? .hidden : .visible, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .navigationDestination(isPresented: $showLibrary) {
                LibraryView(onClose: dismissLibrary)
                    .environmentObject(store)
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

                Button {
                    beginRecordingTransition(playsHaptic: true)
                } label: {
                    Text("Tap and start humming")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HumTheme.labelFaint)
                        .frame(minWidth: 160, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start recording")
                .padding(.bottom, 8)
                .opacity(isRecordTransitioning ? 0 : 1)
                .offset(y: isRecordTransitioning ? 40 : 0)
                .blur(radius: isRecordTransitioning ? 5 : 0)
                .animation(reduceMotion ? nil : HumMotion.bottomHintExit, value: isRecordTransitioning)
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
        .font(.system(size: 32, weight: .regular))
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

    private var hidesNavigationBar: Bool {
        phase == .processing
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
                    .foregroundStyle(HumTheme.glyphInk.opacity(recordWaveOpacity))
                    .frame(width: recordButtonSize * 0.36, height: recordButtonSize * 0.31)
            }
            .overlay {
                // Breathing darkens the button itself without drawing a separate rim.
                Circle()
                    .fill(Color.black.opacity(recordButtonDepthOpacity))
                    .padding(7)
                    .allowsHitTesting(false)
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(recordButtonPressedHighlightOpacity),
                                Color.black.opacity(recordButtonPressedShadowOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .padding(8)
                    .allowsHitTesting(false)
            }
            .brightness(recordButtonBrightness)
            .shadow(
                color: .black.opacity(recordButtonShadowOpacity),
                radius: recordButtonShadowRadius,
                y: recordButtonShadowY
            )
            .frame(width: recordButtonSize, height: recordButtonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start recording")
        .position(captureButtonPosition(in: screenSize))
        .animation(reduceMotion ? nil : BreathingMotion.travel, value: isRecordButtonBreathing)
        .animation(reduceMotion ? nil : HumScopedMotion.press, value: isRecordButtonPressed)
        .animation(reduceMotion ? nil : HumMotion.buttonDescend, value: isRecordTransitioning)
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

    private var recordButtonDepthOpacity: Double {
        if isRecordButtonPressed { return 0 }
        return isRecordButtonBreathing ? 0 : 0.025
    }

    private var recordWaveOpacity: Double {
        isRecordButtonBreathing ? 0.65 : 0.6
    }

    private var recordButtonBrightness: Double {
        if isRecordButtonPressed { return 0 }
        return isRecordButtonBreathing ? 0 : -0.03
    }

    private var recordButtonPressedHighlightOpacity: Double {
        if isRecordButtonPressed { return 0 }
        return isRecordButtonBreathing ? 0 : 0.0
    }

    private var recordButtonPressedShadowOpacity: Double {
        if isRecordButtonPressed { return 0 }
        return isRecordButtonBreathing ? 0 : 0.0
    }

    private var recordButtonShadowOpacity: Double {
        if isRecordButtonPressed { return 0 }
        return isRecordButtonBreathing ? 0 : 0.05
    }

    private var recordButtonShadowRadius: CGFloat {
        if isRecordButtonPressed { return 0 }
        return isRecordButtonBreathing ? 0 : 8
    }

    private var recordButtonShadowY: CGFloat {
        if isRecordButtonPressed { return 1 }
        return isRecordButtonBreathing ? 1 : 4
    }

    private var recordButtonBloomOpacity: Double {
        if isRecordButtonPressed { return 1.16 }
        if isRecordTransitioning { return 1 }
        return isRecordButtonBreathing ? 1.16 : 1.18
    }

    private var recordButtonBloomScale: CGFloat {
        if isRecordButtonPressed { return 1.48 }
        if isRecordTransitioning { return 1.35 }
        return isRecordButtonBreathing ? 2 : 3
    }

    private var captureButtonBloomOpacity: Double {
        recorder.isPaused ? 0.42 : 0.42
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
                withAnimation(reduceMotion ? nil : HumScopedMotion.press) {
                    isRecordButtonPressed = true
                }
            }
            .onEnded { _ in
                guard !isRecordingPhase else { return }
                withAnimation(reduceMotion ? nil : HumScopedMotion.press) {
                    isRecordButtonPressed = false
                }
            }
    }

    private func handleRecordButtonTap() {
        guard !isRecordingPhase else { return }
        beginRecordingTransition(playsHaptic: false)
    }

    private func presentLibrary() {
        guard !showLibrary, !isPreparingLibraryPresentation else { return }
        Haptics.selection()
        libraryPresentationTask?.cancel()
        isPreparingLibraryPresentation = true
        libraryPresentationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            showLibrary = true
        }
    }

    private func dismissLibrary() {
        libraryPresentationTask?.cancel()
        showLibrary = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            guard !showLibrary else { return }
            isPreparingLibraryPresentation = false
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
            withAnimation(reduceMotion ? nil : BreathingMotion.travel) {
                isRecordButtonBreathing = true
            }
            try? await Task.sleep(for: BreathingMotion.travelDuration)
            try? await Task.sleep(for: BreathingMotion.topHold)

            withAnimation(reduceMotion ? nil : BreathingMotion.travel) {
                isRecordButtonBreathing = false
            }
            try? await Task.sleep(for: BreathingMotion.travelDuration)
        }
    }


    private func finishRecording() {
        guard phase == .recording, !isFinishingRecording, !isDismissingRecording else { return }
        isFinishingRecording = true
        startRecordingTask?.cancel()

        guard let result = recorder.stop() else {
            backToIdle()
            return
        }
        freshAudioURL = result.url
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.28)) {
                    phase = .processing
                }
            }
        }

        Task.detached(priority: .userInitiated) {
            let notes = (try? PitchTracker.extractNotes(from: result.url)) ?? []
            let analysis = ChordEngine.analyze(notes: notes, duration: result.duration)

            // Hold the processing state long enough for the reveal to feel deliberate.
            try? await Task.sleep(for: .seconds(1.8))

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

    private func restartRecording() {
        guard phase == .recording, !isFinishingRecording, !isDismissingRecording else { return }
        recorder.cancel()
        do {
            try recorder.start()
        } catch {
            cancelRecording()
        }
    }

    private func cancelRecording() {
        guard phase == .recording, !isFinishingRecording, !isDismissingRecording else { return }
        startRecordingTask?.cancel()

        // Stage 1: the recording screen dissolves — texts blur away and the halo
        // sinks back below the horizon (ListeningView reacts to isDismissing).
        isDismissingRecording = true
        recorder.cancel()
        freshAudioURL = nil

        Task {
            try? await Task.sleep(for: .milliseconds(560))
            await MainActor.run {
                // Stage 2: swap to the (identically charcoal) idle screen while the
                // record button is still parked below the screen edge.
                withAnimation(HumMotion.phaseChange) {
                    phase = .idle
                }
                isFinishingRecording = false
                isDismissingRecording = false
            }

            // Stage 3: a beat later, release the button so it rises back up while
            // the headline fades in from the top and the hint from the bottom.
            try? await Task.sleep(for: .milliseconds(90))
            await MainActor.run {
                withAnimation(HumMotion.buttonDescend) {
                    isRecordTransitioning = false
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
