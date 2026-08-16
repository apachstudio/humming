import SwiftUI

/// Recording screen (Figma flow 3, screen 4): near-black canvas with a
/// white bloom rising from the bottom that breathes with your voice.
/// Tap anywhere to stop · hold to pause/resume.
struct ListeningView: View {
    @ObservedObject var recorder: AudioRecorder
    var onStop: () -> Void

    var body: some View {
        ZStack {
            HumTheme.charcoal.ignoresSafeArea()

            // The bloom: light fills the screen as you hum.
            VStack {
                Spacer()
                LiquidGlassBlob()
                    .opacity(recorder.isPaused ? 0.45 : 0.92)
                    .scaleEffect(
                        1 + (recorder.isPaused ? 0 : recorder.currentLevel * 0.10),
                        anchor: .bottom
                    )
                    .offset(y: 300 - (recorder.isPaused ? 0 : recorder.currentLevel * 60))
                    .animation(.easeOut(duration: 0.15), value: recorder.currentLevel)
                    .animation(.easeInOut(duration: 0.3), value: recorder.isPaused)
            }
            .ignoresSafeArea()
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

                // Gesture hints resting on the bloom.
                VStack(spacing: 14) {
                    Text("Tap to stop")
                    Text(recorder.isPaused ? "Hold to resume" : "Hold to pause")
                }
                .font(.system(size: 12, weight: .medium))
                .kerning(-0.12)
                .foregroundStyle(HumTheme.hintGray)
                .padding(.bottom, 32)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onStop() }
        .onLongPressGesture(minimumDuration: 0.35) {
            recorder.togglePause()
        }
        .preferredColorScheme(.dark)
        .onChange(of: recorder.elapsed) { _, newValue in
            if newValue >= AudioRecorder.maxDuration {
                onStop()
            }
        }
    }
}

#Preview {
    ListeningView(recorder: AudioRecorder(), onStop: {})
}
