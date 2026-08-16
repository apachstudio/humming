import SwiftUI

/// Recording screen (Figma flow 3, screen 4): the home record circle
/// remains on the near-black canvas and its white halo breathes with your voice.
/// Tap anywhere to stop · hold to pause/resume.
struct ListeningView: View {
    @ObservedObject var recorder: AudioRecorder
    let recordCircleNamespace: Namespace.ID
    var onStop: () -> Void

    @State private var controlsVisible = false

    var body: some View {
        let levelBoost = recorder.isPaused ? 0 : recorder.currentLevel

        ZStack {
            HumTheme.charcoal.ignoresSafeArea()

            // Keep the home circle in place so the transition reads as one
            // continuous object instead of switching to a bottom gradient.
            DarkGlassCircle(
                size: 170,
                bloomOpacity: recorder.isPaused ? 0.38 : 0.82,
                bloomScale: (recorder.isPaused ? 0.94 : 1.12) + levelBoost * 0.32,
                circleAssetName: "liquid-glass-button"
            )
            .matchedGeometryEffect(
                id: "record-circle",
                in: recordCircleNamespace,
                properties: .frame,
                anchor: .center,
                isSource: false
            )
            .scaleEffect(1 + levelBoost * 0.045)
            .animation(.easeOut(duration: 0.15), value: recorder.currentLevel)
            .animation(.easeInOut(duration: 0.3), value: recorder.isPaused)
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
            controlsVisible = false
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

private struct ListeningPreview: View {
    @Namespace private var namespace

    var body: some View {
        ListeningView(
            recorder: AudioRecorder(),
            recordCircleNamespace: namespace,
            onStop: {}
        )
    }
}

#Preview {
    ListeningPreview()
}
