import SwiftUI

/// Recording chrome on the shared charcoal canvas: a discreet timer and
/// the "Tap to stop" hint. The record circle itself lives in `HomeView`
/// so its halo can travel down, then rise again as Stop.
struct ListeningView: View {
    @ObservedObject var recorder: AudioRecorder
    var onStop: () -> Void

    @State private var controlsVisible = false

    var body: some View {
        VStack {
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
                .padding(.bottom, 20)
                .opacity(controlsVisible ? 1 : 0)
                .offset(y: controlsVisible ? 0 : 42)
                .blur(radius: controlsVisible ? 0 : 5)
                .animation(.easeOut(duration: 0.72), value: controlsVisible)
        }
        .allowsHitTesting(false)
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

#Preview {
    ZStack {
        HumTheme.charcoal.ignoresSafeArea()
        ListeningView(recorder: AudioRecorder(), onStop: {})
    }
}
