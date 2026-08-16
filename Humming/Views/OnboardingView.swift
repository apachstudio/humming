import SwiftUI

/// First-launch sequence (Figma flow 3):
/// 1. The "humming" wordmark draws itself as a single stroke.
/// 2. It shrinks upward while the tagline fades in beneath it.
/// 3. Crossfade to home (handled by RootView).
/// Tap anywhere to skip.
struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var drawProgress: CGFloat = 0
    @State private var compact = false
    @State private var finished = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                HumTheme.charcoal.ignoresSafeArea()

                WordmarkView(progress: drawProgress)
                    .frame(width: compact ? 84 : 200)
                    .position(
                        x: width / 2,
                        y: compact ? height * 0.42 : height * 0.5
                    )

                tagline
                    .position(x: width / 2, y: height * 0.56)
                    .opacity(compact ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear { runSequence() }
    }

    /// "Think it / Hum it / Play it" brand tagline.
    private var tagline: some View {
        VStack(spacing: 4) {
            Text("Think it")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Color(hex: 0x8F8F8F))
            Text("Hum it")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(hex: 0xE2E2E2))
            Text("Play it")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
        .kerning(-0.4)
    }

    private func runSequence() {
        // 1. Draw the wordmark stroke.
        withAnimation(.easeInOut(duration: 1.2)) {
            drawProgress = 1
        }
        // 2. Shrink up, reveal the tagline.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                compact = true
            }
        }
        // 3. Hand off to home.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinished()
    }
}

#Preview {
    OnboardingView {}
}
