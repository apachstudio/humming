import SwiftUI

/// First-launch screen (Figma 19:65) with the exit transition
/// from the "Transition animation" frame (19:205): everything
/// slides up as the glass button leaves through the top.
struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var isLeaving = false

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height

            ZStack {
                HumTheme.charcoal.ignoresSafeArea()

                Button {
                    beginTransition()
                } label: {
                    LiquidGlassCircle(size: 137)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Get started")
                .position(
                    x: proxy.size.width / 2,
                    y: isLeaving ? -120 : height * 0.5
                )

                VStack(spacing: 24) {
                    tagline
                    Text("Hum a melody and get the\nchords and MIDI instantly")
                        .font(.system(size: 16))
                        .foregroundStyle(HumTheme.mutedOnDark)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .position(
                    x: proxy.size.width / 2,
                    y: isLeaving ? height * 0.52 : height * 0.79
                )
                .opacity(isLeaving ? 0 : 1)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    /// "Think it / Hum it / Play it" brand tagline.
    private var tagline: some View {
        VStack(spacing: 2) {
            Text("Think it")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color(hex: 0x8F8F8F))
            Text("Hum it")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color(hex: 0xE2E2E2))
            Text("Play it")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
        }
        .kerning(-0.6)
    }

    private func beginTransition() {
        guard !isLeaving else { return }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.85)) {
            isLeaving = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            onFinished()
        }
    }
}

#Preview {
    OnboardingView {}
}
