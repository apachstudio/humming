import SwiftUI

/// Post-recording loading state (Figma 19:124 / 19:198):
/// "Capturing melody..." then "Transcribing melody..." with the
/// glass button pulsing at the bottom.
struct ProcessingView: View {
    @State private var stage = 0
    @State private var shimmerPhase: CGFloat = -0.9

    private let stages = ["Capturing melody...", "Transcribing melody..."]
    private let processingFont = Font.system(size: 12, weight: .medium)

    var body: some View {
        ZStack {
            HumTheme.charcoal.ignoresSafeArea()

            Text(stages[stage])
                .font(processingFont)
                .foregroundStyle(shimmerGradient)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: stage)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            shimmerPhase = -0.9
            withAnimation(.linear(duration: 3.8).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.9
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                stage = 1
            }
        }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                HumTheme.labelFaint,
                HumTheme.labelFaint,
                Color.white.opacity(0.34),
                HumTheme.labelFaint,
                HumTheme.labelFaint
            ],
            startPoint: UnitPoint(x: shimmerPhase - 0.55, y: 0.5),
            endPoint: UnitPoint(x: shimmerPhase + 0.55, y: 0.5)
        )
    }
}

#Preview {
    ProcessingView()
}
