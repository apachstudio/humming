import SwiftUI

/// First-launch sequence:
/// 1. The "humming" wordmark fades in with a restrained micro-scale.
/// 2. The wordmark fades away cleanly.
/// 3. "Think it", "Hum it", and "Play it" fade in one after another.
/// Tap anywhere to skip.
struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.992
    @State private var logoOffset: CGFloat = 2
    @State private var thinkOpacity: Double = 0
    @State private var humOpacity: Double = 0
    @State private var playOpacity: Double = 0
    @State private var thinkOffset: CGFloat = 7
    @State private var humOffset: CGFloat = 7
    @State private var playOffset: CGFloat = 7
    @State private var finished = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                HumTheme.charcoal.ignoresSafeArea()

                WordmarkView()
                    .frame(width: min(width * 0.3, 214))
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .offset(y: logoOffset)
                    .position(x: width / 2, y: height * 0.48)

                tagline
                    .position(x: width / 2, y: height * 0.5)
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
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color(hex: 0x3D3D3D))
                .opacity(thinkOpacity)
                .offset(y: thinkOffset)

            Text("Hum it")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Color(hex: 0x919191))
                .opacity(humOpacity)
                .offset(y: humOffset)

            Text("Play it")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color(hex: 0xEFEFEF))
                .opacity(playOpacity)
                .offset(y: playOffset)
        }
        .multilineTextAlignment(.center)
    }

    private func runSequence() {
        withAnimation(.easeOut(duration: 0.85)) {
            logoOpacity = 1
            logoScale = 1
            logoOffset = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.easeInOut(duration: 0.65)) {
                logoOpacity = 0
                logoScale = 0.998
                logoOffset = -3
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.35) {
            withAnimation(.easeOut(duration: 0.6)) {
                thinkOpacity = 1
                thinkOffset = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.95) {
            withAnimation(.easeOut(duration: 0.6)) {
                humOpacity = 1
                humOffset = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.55) {
            withAnimation(.easeOut(duration: 0.6)) {
                playOpacity = 1
                playOffset = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.1) {
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
