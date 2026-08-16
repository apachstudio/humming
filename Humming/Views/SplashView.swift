import SwiftUI

struct SplashView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.35)) {
                model.dismissSplash()
            }
        } label: {
            VStack(spacing: 16) {
                WaveformBars()
                    .padding(28)
                    .background(Circle().fill(Color(.secondarySystemFill)))
                    .padding(.bottom, 8)

                Text("humming")
                    .font(.system(.largeTitle, design: .serif, weight: .medium))
                    .italic()

                VStack(spacing: 2) {
                    Text("Think it")
                        .foregroundStyle(.secondary)
                    Text("Hum it")
                    Text("Play it")
                }
                .font(.largeTitle)
                .fontWeight(.bold)

                Text("Hum a melody and get the chords and MIDI instantly")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
    }
}
