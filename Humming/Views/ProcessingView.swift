import SwiftUI

struct ProcessingView: View {
    var body: some View {
        VStack(spacing: 20) {
            WaveformBars()
                .scaleEffect(1.4)
                .phaseAnimator([false, true]) { view, on in
                    view.scaleEffect(on ? 1.08 : 0.92).opacity(on ? 1 : 0.7)
                }
                .padding(36)
                .background(Circle().fill(Color(.secondarySystemFill)))

            Text("Translating your hum...")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Analyzing pitch, frequency & chords")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
    }
}
