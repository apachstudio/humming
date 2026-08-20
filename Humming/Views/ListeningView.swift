import SwiftUI

/// Recording screen (Figma flow 3, screen 4): timer, stop affordance, and the PR 1 halo.
struct ListeningView: View {
    @ObservedObject var recorder: AudioRecorder
    var isFinishing = false
    var isDismissing = false
    var onStop: () -> Void
    var onCancel: () -> Void

    @State private var introBloom = false
    @State private var timerVisible = false
    private let haloTuning = ListeningHaloTuning.standard

    var body: some View {
        GeometryReader { proxy in
            let bloomSize = max(proxy.size.width, proxy.size.height) * 1.1
            let levelBoost = recorder.isPaused ? 0 : CGFloat(recorder.currentLevel)

            ZStack {
                HumTheme.charcoal.ignoresSafeArea()

                recordingHalo(
                    bloomSize: bloomSize,
                    levelBoost: levelBoost,
                    screenSize: proxy.size,
                    tuning: haloTuning
                )

                Text(recordingTimeString)
                    .font(.system(size: 24, weight: .light).monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.36))
                    .contentTransition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .ignoresSafeArea()
                    .opacity(textVisible ? 1 : 0)
                    .offset(y: textVisible ? 0 : -18)
                    .blur(radius: textVisible ? 0 : 5)
                    .animation(HumMotion.recordingTextIn, value: timerVisible)
                    .animation(HumMotion.textExit, value: isFinishing)
                    .animation(HumMotion.textExit, value: isDismissing)

                VStack(spacing: 0) {
                    Spacer()

                    Text("Tap to finish")
                        .font(.system(size: 12, weight: .medium))
                        .kerning(-0.12)
                        .foregroundStyle(Color.black.opacity(0.4))
                        .padding(.bottom, 32)
                        .opacity(textVisible ? 1 : 0)
                        .offset(y: textVisible ? 0 : 42)
                        .blur(radius: textVisible ? 0 : 5)
                        .animation(HumMotion.stopHintIn, value: timerVisible)
                        .animation(HumMotion.textExit, value: isFinishing)
                        .animation(HumMotion.textExit, value: isDismissing)
                }
            }
        }
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Keep vibing")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.26))
                    .opacity(textVisible ? 1 : 0)
                    .offset(y: textVisible ? 0 : -18)
                    .blur(radius: textVisible ? 0 : 5)
                    .animation(HumMotion.recordingTextIn, value: timerVisible)
                    .animation(HumMotion.textExit, value: isFinishing)
                    .animation(HumMotion.textExit, value: isDismissing)
            }

            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .navigationBarTrailing) {
                    dismissButton
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    dismissButton
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDismissing else { return }
            Haptics.medium()
            onStop()
        }
        .simultaneousGesture(dismissSwipeGesture)
        .onAppear {
            introBloom = false
            timerVisible = false
            withAnimation(.spring(response: 1.05, dampingFraction: 0.84)) {
                introBloom = true
            }
            withAnimation(HumMotion.recordingTextIn) {
                timerVisible = true
            }
        }
        .onChange(of: recorder.elapsed) { _, newValue in
            if newValue >= AudioRecorder.maxDuration {
                onStop()
            }
        }
        .onChange(of: isDismissing) { _, dismissing in
            guard dismissing else { return }
            // The halo sinks back below the horizon while the texts blur away.
            withAnimation(.spring(response: 0.85, dampingFraction: 0.92)) {
                introBloom = false
            }
        }
    }

    private var recordingTimeString: String {
        recorder.elapsed.clockString
    }

    private var textVisible: Bool {
        timerVisible && !isFinishing && !isDismissing
    }

    /// Bare chevron dismiss affordance — no glass background, just the icon.
    private var dismissButton: some View {
        Button {
            Haptics.light()
            onCancel()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.46))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss recording")
        .opacity(textVisible ? 1 : 0)
        .animation(HumMotion.recordingTextIn, value: timerVisible)
        .animation(HumMotion.textExit, value: isFinishing)
        .animation(HumMotion.textExit, value: isDismissing)
    }

    private var dismissSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard !isFinishing, !isDismissing else { return }
                let translation = value.translation
                let isDownwardDismiss = translation.height > 90 && abs(translation.width) < translation.height * 0.8
                guard isDownwardDismiss else { return }

                Haptics.light()
                onCancel()
            }
    }

    @ViewBuilder
    private func recordingHalo(
        bloomSize: CGFloat,
        levelBoost: CGFloat,
        screenSize: CGSize,
        tuning: ListeningHaloTuning
    ) -> some View {
        ZStack {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let liveLevel = recorder.isPaused ? 0 : max(0.08, levelBoost)
                let pulse = 1 + sin(time * 1.8) * 0.08 * tuning.glowPulse + Double(liveLevel) * 0.08
                let drift = bloomSize * 0.035 * tuning.glowDrift
                let driftX = cos(time * 0.72) * drift
                let driftY = sin(time * 0.9) * drift * 0.7

                Circle()
                    .fill(Color.white.opacity(0.38 * tuning.glowStrength))
                    .frame(width: bloomSize * 1.28, height: bloomSize * 1.28)
                    .blur(radius: bloomSize * (0.16 + 0.055 * tuning.glowPulse))
                    .scaleEffect(pulse)
                    .offset(x: driftX, y: driftY)
                    .blendMode(.plusLighter)
            }

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let liveLevel = recorder.isPaused ? 0 : max(0.08, levelBoost)
                let waveCount = max(2, Int(tuning.waveCount.rounded()))

                ZStack {
                    ForEach(0..<waveCount, id: \.self) { index in
                        let ring = CGFloat(index)
                        let drift = CGFloat(time * tuning.waveSpeed) * (1.5 + ring * 0.28)
                        let diameter = bloomSize * (0.62 + ring * 0.105 + liveLevel * 0.045)
                        let amplitude = bloomSize * (0.003 + tuning.waveAmplitude * 0.035 + Double(liveLevel) * 0.024) * (1 + Double(ring) * 0.24)
                        let opacity = tuning.waveOpacity - Double(ring) * 0.032 + Double(liveLevel) * 0.13

                        MelodyHaloWave(
                            phase: drift + ring * 1.7,
                            amplitude: amplitude,
                            frequency: 6 + ring * 2
                        )
                        .stroke(Color.white.opacity(max(0.02, opacity)), lineWidth: max(1, bloomSize * 0.0038))
                        .frame(width: diameter, height: diameter)
                        .blur(radius: bloomSize * (0.004 + ring * 0.002))
                        .scaleEffect(1 + liveLevel * (0.035 + ring * 0.012))
                        .rotationEffect(.degrees(Double(ring) * 18 + time * (3 + Double(index)) * tuning.waveSpeed))
                    }
                }
                .blendMode(.plusLighter)
            }
            .frame(width: bloomSize, height: bloomSize)

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let liveLevel = recorder.isPaused ? 0 : max(0.08, levelBoost)
                let corePulse = 1 + sin(time * 2.25) * 0.028 * tuning.glowPulse + Double(liveLevel) * 0.035

                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.95 * tuning.glowStrength), location: 0),
                                .init(color: Color.white.opacity(0.54 * tuning.glowStrength), location: 0.28),
                                .init(color: Color.white.opacity(0.16 * tuning.glowStrength), location: 0.62),
                                .init(color: .clear, location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: bloomSize * 0.5
                        )
                    )
                    .frame(width: bloomSize, height: bloomSize)
                    .blur(radius: bloomSize * 0.055)
                    .scaleEffect(corePulse)
            }
        }
        .opacity((recorder.isPaused ? 0.52 : 0.92) * (introBloom ? 1 : 0.32))
        .scaleEffect(((introBloom ? 1 : 0.28) + levelBoost * 0.08) * tuning.haloScale)
        .position(
            x: screenSize.width / 2,
            y: screenSize.height + (introBloom ? 120 : 300) - tuning.haloLift - levelBoost * 70
        )
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.12), value: recorder.currentLevel)
        .animation(.easeInOut(duration: 0.3), value: recorder.isPaused)
        .animation(.spring(response: 1.05, dampingFraction: 0.84), value: introBloom)
    }
}

private struct ListeningHaloTuning: Codable, Equatable {
    var waveCount: Double
    var waveAmplitude: Double
    var waveSpeed: Double
    var waveOpacity: Double
    var glowStrength: Double
    var glowPulse: Double
    var glowDrift: Double
    var haloLift: Double
    var haloScale: Double

    static let standard = ListeningHaloTuning(
        waveCount: 4,
        waveAmplitude: 0.11,
        waveSpeed: 2.16,
        waveOpacity: 0.29,
        glowStrength: 1.06,
        glowPulse: 1,
        glowDrift: 0.55,
        haloLift: 0,
        haloScale: 1
    )
}


private struct MelodyHaloWave: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, amplitude) }
        set {
            phase = newValue.first
            amplitude = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2
        let sampleCount = 180
        var path = Path()

        for sample in 0...sampleCount {
            let progress = CGFloat(sample) / CGFloat(sampleCount)
            let angle = progress * .pi * 2
            let primary = sin(angle * frequency + phase)
            let secondary = sin(angle * (frequency * 0.5 + 1.5) - phase * 0.72)
            let radius = baseRadius + primary * amplitude + secondary * amplitude * 0.42
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if sample == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

#Preview {
    NavigationStack {
        ListeningView(
            recorder: AudioRecorder(),
            onStop: {},
            onCancel: {}
        )
    }
}
