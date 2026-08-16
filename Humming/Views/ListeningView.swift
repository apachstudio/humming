import SwiftUI

/// Recording screen (Figma flow 3, screen 4): near-black canvas with a
/// white bloom rising from the bottom that breathes with your voice.
/// Tap anywhere to stop · hold to pause/resume.
struct ListeningView: View {
    @ObservedObject var recorder: AudioRecorder
    var onStop: () -> Void

    @State private var introBloom = false
    @State private var controlsVisible = false

    var body: some View {
        GeometryReader { proxy in
            let bloomSize = max(proxy.size.width, proxy.size.height) * 0.86
            let levelBoost = recorder.isPaused ? 0 : recorder.currentLevel

            ZStack {
                HumTheme.charcoal.ignoresSafeArea()

                // Circular bloom that grows from the home button's glow into the recording field.
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.17))
                        .frame(width: bloomSize * 1.28, height: bloomSize * 1.28)
                        .blur(radius: bloomSize * 0.2)

                    Circle()
                        .fill(
                            RadialGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.95), location: 0),
                                    .init(color: Color.white.opacity(0.54), location: 0.28),
                                    .init(color: Color.white.opacity(0.16), location: 0.62),
                                    .init(color: .clear, location: 1)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: bloomSize * 0.5
                            )
                        )
                        .frame(width: bloomSize, height: bloomSize)
                        .blur(radius: bloomSize * 0.055)
                }
                .opacity((recorder.isPaused ? 0.52 : 0.92) * (introBloom ? 1 : 0.32))
                .scaleEffect((introBloom ? 1 : 0.28) + levelBoost * 0.08)
                .position(
                    x: proxy.size.width / 2,
                    y: proxy.size.height + (introBloom ? 120 : 300) - levelBoost * 70
                )
                .animation(.easeOut(duration: 0.15), value: recorder.currentLevel)
                .animation(.easeInOut(duration: 0.3), value: recorder.isPaused)
                .animation(.spring(response: 1.05, dampingFraction: 0.84), value: introBloom)
                .allowsHitTesting(false)

                VStack {
                    // Discreet timer.
                    Text(recorder.isPaused
                         ? "Paused · \(recorder.elapsed.clockString)"
                         : recorder.elapsed.clockString)
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(HumTheme.hintGray)
                        .padding(.top, 12)
                        .contentTransition(.numericText())

                    Spacer()

                    Text("Tap to stop")
                        .font(.system(size: 12, weight: .medium))
                        .kerning(-0.12)
                        .foregroundStyle(Color(hex: 0xB8B8B8))
                        .padding(.bottom, 32)
                        .opacity(controlsVisible ? 1 : 0)
                        .offset(y: controlsVisible ? 0 : 42)
                        .blur(radius: controlsVisible ? 0 : 5)
                        .animation(.easeOut(duration: 0.72), value: controlsVisible)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onStop() }
            .preferredColorScheme(.dark)
            .onAppear {
                introBloom = false
                controlsVisible = false
                withAnimation(.spring(response: 1.05, dampingFraction: 0.84)) {
                    introBloom = true
                }
                withAnimation(.easeOut(duration: 0.72).delay(0.18)) {
                    controlsVisible = true
                }
            }
            .onChange(of: recorder.elapsed) { _, newValue in
                if newValue >= AudioRecorder.maxDuration {
                    onStop()
                }
            }
        }
    }
}

#Preview {
    ListeningView(recorder: AudioRecorder(), onStop: {})
}
