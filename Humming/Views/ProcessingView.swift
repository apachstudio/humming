import SwiftUI

/// Post-recording loading state that visually continues the ListeningView halo.
struct ProcessingView: View {
    @State private var introBloom = false
    @State private var processingTextVisible = false

    var body: some View {
        GeometryReader { proxy in
            let bloomSize = max(proxy.size.width, proxy.size.height) * 1.1

            ZStack {
                HumTheme.charcoal.ignoresSafeArea()

                processingHalo(
                    bloomSize: bloomSize,
                    screenSize: proxy.size
                )

                Text("Processing hum...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.36))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .opacity(processingTextVisible ? 1 : 0)
                    .offset(y: processingTextVisible ? 0 : 18)
                    .blur(radius: processingTextVisible ? 0 : 5)
                    .animation(HumMotion.recordingTextIn, value: processingTextVisible)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            introBloom = false
            processingTextVisible = false
            withAnimation(.spring(response: 1.05, dampingFraction: 0.84)) {
                introBloom = true
            }
            withAnimation(HumMotion.recordingTextIn) {
                processingTextVisible = true
            }
        }
    }

    @ViewBuilder
    private func processingHalo(
        bloomSize: CGFloat,
        screenSize: CGSize
    ) -> some View {
        ZStack {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let liveLevel = 0.08
                let pulse = 1 + sin(time * 1.8) * 0.08 + liveLevel * 0.08
                let drift = bloomSize * 0.035 * 0.55
                let driftX = cos(time * 0.72) * drift
                let driftY = sin(time * 0.9) * drift * 0.7

                Circle()
                    .fill(Color.white.opacity(0.38 * 1.06))
                    .frame(width: bloomSize * 1.28, height: bloomSize * 1.28)
                    .blur(radius: bloomSize * (0.16 + 0.055))
                    .scaleEffect(pulse)
                    .offset(x: driftX, y: driftY)
                    .blendMode(.plusLighter)
            }

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let liveLevel = 0.08

                ZStack {
                    ForEach(0..<4, id: \.self) { index in
                        let ring = CGFloat(index)
                        let drift = CGFloat(time * 2.16) * (1.5 + ring * 0.28)
                        let diameter = bloomSize * (0.62 + ring * 0.105 + liveLevel * 0.045)
                        let amplitude = bloomSize * (0.003 + 0.11 * 0.035 + liveLevel * 0.024) * (1 + Double(ring) * 0.24)
                        let opacity = 0.29 - Double(ring) * 0.032 + liveLevel * 0.13

                        ProcessingHaloWave(
                            phase: drift + ring * 1.7,
                            amplitude: amplitude,
                            frequency: 5 + ring * 2
                        )
                        .stroke(Color.white.opacity(max(0.02, opacity)), lineWidth: max(1, bloomSize * 0.0038))
                        .frame(width: diameter, height: diameter)
                        .blur(radius: bloomSize * (0.004 + ring * 0.002))
                        .scaleEffect(1 + liveLevel * (0.035 + ring * 0.012))
                        .rotationEffect(.degrees(Double(ring) * 18 + time * (3 + Double(index)) * 2.16))
                    }
                }
                .blendMode(.plusLighter)
            }
            .frame(width: bloomSize, height: bloomSize)

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let liveLevel = 0.08
                let corePulse = 1 + sin(time * 2.25) * 0.028 + liveLevel * 0.035

                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.95 * 1.06), location: 0),
                                .init(color: Color.white.opacity(0.54 * 1.06), location: 0.28),
                                .init(color: Color.white.opacity(0.16 * 1.06), location: 0.62),
                                .init(color: .clear, location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: bloomSize * 0.5
                        )
                    )
                    .frame(width: bloomSize, height: bloomSize)
                    .blur(radius: bloomSize * 0.055)
                    .scaleEffect(corePulse)
            }
        }
        .opacity(0.92 * (introBloom ? 1 : 0.32))
        .scaleEffect(introBloom ? 1 : 0.28)
        .position(
            x: screenSize.width / 2,
            y: screenSize.height + (introBloom ? 120 : 300)
        )
        .allowsHitTesting(false)
        .animation(.spring(response: 1.05, dampingFraction: 0.84), value: introBloom)
    }
}

private struct ProcessingHaloWave: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, amplitude) }
        set {
            phase = newValue.first
            amplitude = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2
        let sampleCount = 180
        var path = Path()

        for sample in 0...sampleCount {
            let progress = CGFloat(sample) / CGFloat(sampleCount)
            let angle = progress * .pi * 2
            let primary = sin(angle * frequency + phase)
            let secondary = sin(angle * (frequency * 0.5 + 1.5) - phase * 0.72)
            let radius = baseRadius + primary * amplitude + secondary * amplitude * 0.42
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if sample == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

#Preview {
    ProcessingView()
}
