import SwiftUI

/// Post-recording loading state that visually continues the ListeningView halo.
struct ProcessingView: View {
    @State private var introBloom = false

    var body: some View {
        GeometryReader { proxy in
            let bloomSize = max(proxy.size.width, proxy.size.height) * 1.1

            ZStack {
                HumTheme.charcoal.ignoresSafeArea()

                processingHalo(
                    bloomSize: bloomSize,
                    screenSize: proxy.size
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            introBloom = false
            withAnimation(.spring(response: 1.05, dampingFraction: 0.84)) {
                introBloom = true
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
                let pulse = 1 + sin(time * 1.45) * 0.075
                let driftX = cos(time * 0.68) * bloomSize * 0.018
                let driftY = sin(time * 0.84) * bloomSize * 0.012

                Circle()
                    .fill(Color.white.opacity(0.38))
                    .frame(width: bloomSize * 1.28, height: bloomSize * 1.28)
                    .blur(radius: bloomSize * 0.2)
                    .scaleEffect(pulse)
                    .offset(x: driftX, y: driftY)
                    .blendMode(.plusLighter)
            }

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    ForEach(0..<4, id: \.self) { index in
                        let ring = CGFloat(index)
                        let diameter = bloomSize * (0.62 + ring * 0.11)
                        let amplitude = bloomSize * (0.018 + Double(ring) * 0.004)
                        let phase = CGFloat(time) * (0.82 + ring * 0.16) + ring * 1.7

                        ProcessingHaloWave(
                            phase: phase,
                            amplitude: amplitude,
                            frequency: 5 + ring * 2
                        )
                        .stroke(Color.white.opacity(0.19 - Double(ring) * 0.035), lineWidth: max(1, bloomSize * 0.0038))
                        .frame(width: diameter, height: diameter)
                        .blur(radius: bloomSize * (0.004 + ring * 0.002))
                        .rotationEffect(.degrees(Double(ring) * 18 + time * (2 + Double(index))))
                    }
                }
                .blendMode(.plusLighter)
            }
            .frame(width: bloomSize, height: bloomSize)

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let corePulse = 1 + sin(time * 1.9) * 0.035

                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.9), location: 0),
                                .init(color: Color.white.opacity(0.48), location: 0.28),
                                .init(color: Color.white.opacity(0.14), location: 0.62),
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
        .opacity(introBloom ? 0.86 : 0.28)
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
