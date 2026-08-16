import SwiftUI

/// Recording screen (Figma 5:134): black background, glowing coral orb,
/// "Listening...", live waveform and a stop button.
struct ListeningView: View {
    @ObservedObject var recorder: AudioRecorder
    var onStop: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer()

                orb
                    .padding(.bottom, 48)

                Text("Listening...")
                    .font(.system(size: 24, weight: .light))
                    .kerning(0.07)
                    .foregroundStyle(.white)
                    .padding(.bottom, 32)

                WaveformBars(levels: recorder.levels)

                Spacer()

                stopControl
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: recorder.elapsed) { _, newValue in
            if newValue >= AudioRecorder.maxDuration {
                onStop()
            }
        }
    }

    private var topBar: some View {
        ZStack {
            Text(recorder.elapsed.clockString)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .monospacedDigit()
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1), in: Capsule())

            HStack {
                Button(action: onCancel) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Cancel recording")

                Spacer()

                Menu {
                    Button("Discard hum", role: .destructive, action: onCancel)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    private var orb: some View {
        Circle()
            .fill(HumTheme.orbGradient)
            .frame(width: 288, height: 288)
            .shadow(color: HumTheme.coral.opacity(0.6), radius: 70)
            .scaleEffect(1 + recorder.currentLevel * 0.06)
            .animation(.easeOut(duration: 0.12), value: recorder.currentLevel)
    }

    private var stopControl: some View {
        VStack(spacing: 12) {
            Button(action: onStop) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 5)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black)
                        .frame(width: 24, height: 24)
                }
            }
            .accessibilityLabel("Stop recording")

            Text("Stop")
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.6))
        }
    }
}

#Preview {
    ListeningView(recorder: AudioRecorder(), onStop: {}, onCancel: {})
}
