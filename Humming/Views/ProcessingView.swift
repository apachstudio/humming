import SwiftUI

/// Post-recording loading state (Figma 19:124 / 19:198):
/// "Capturing melody..." then "Transcribing melody..." with the
/// glass button pulsing at the bottom.
struct ProcessingView: View {
    @State private var stage = 0
    @State private var pulsing = false

    private let stages = ["Capturing melody...", "Transcribing melody..."]

    var body: some View {
        ZStack {
            HumTheme.charcoal.ignoresSafeArea()

            Text(stages[stage])
                .font(.system(size: 16))
                .foregroundStyle(HumTheme.textOnDark)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: stage)

            VStack {
                Spacer()
                LiquidGlassCircle(size: 137)
                    .scaleEffect(pulsing ? 1.07 : 0.97)
                    .animation(
                        .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                        value: pulsing
                    )
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            pulsing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                stage = 1
            }
        }
    }
}

#Preview {
    ProcessingView()
}
