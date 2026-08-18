import SwiftUI

enum LiquidGlassNavTone {
    case light
    case dark

    var foreground: Color {
        switch self {
        case .light: HumTheme.ink
        case .dark: Color.white.opacity(0.86)
        }
    }
}

struct LiquidGlassNavIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var tone: LiquidGlassNavTone = .dark
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            glassIconLabel
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var glassIconLabel: some View {
        let label = Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tone.foreground)
            .frame(width: 44, height: 44)
            .contentShape(Circle())

        if #available(iOS 26.0, *) {
            label
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            label
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(tone.foreground.opacity(0.12), lineWidth: 1))
        }
    }
}

struct LiquidGlassTopNavBar<Content: View>: View {
    var tone: LiquidGlassNavTone = .dark
    @ViewBuilder var content: Content

    var body: some View {
        let bar = HStack(spacing: 8) {
            content
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 56)

        if #available(iOS 26.0, *) {
            bar
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
        } else {
            bar
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(tone.foreground.opacity(0.1), lineWidth: 1))
        }
    }
}

/// The circular "liquid glass" button from the Figma design system:
/// a glowing white orb with soft halo and the brand wave glyph inside.
struct LiquidGlassCircle: View {
    var size: CGFloat
    var showsGlyph: Bool = true

    var body: some View {
        ZStack {
            Image("liquid-glass-button")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)

            if showsGlyph {
                WaveGlyphView(color: HumTheme.glyphInk)
                    .frame(width: size * 0.46, height: size * 0.39)
                    .offset(y: size * 0.02)
            }
        }
    }
}

/// The dark embossed record button: a charcoal disc lifted by a thin rim light
/// (strongest at the top-left), a soft white bloom, a drop shadow, and the
/// brand wave glyph centred inside.
struct DarkGlassCircle: View {
    var size: CGFloat
    var showsGlyph: Bool = true
    var showsBloom: Bool = true
    var bloomOpacity: Double = 1
    var bloomScale: CGFloat = 1
    var circleAssetName: String?

    var body: some View {
        ZStack {
            Group {
                if showsBloom {
                    // Outer ambient bloom gives the dark disc a subtle luminous presence.
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: size * 1.35, height: size * 1.35)
                        .blur(radius: size * 0.28)

                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: size * 1.08, height: size * 1.08)
                        .blur(radius: size * 0.14)
                }
            }
            .opacity(bloomOpacity)
            .scaleEffect(bloomScale)

            if let circleAssetName {
                Image(circleAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: 0x323232), Color(hex: 0x282828)],
                            center: UnitPoint(x: 0.38, y: 0.32),
                            startRadius: 0,
                            endRadius: size * 0.12
                        )
                    )
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.5), location: 0),
                                    .init(color: .white.opacity(0.06), location: 0.35),
                                    .init(color: .clear, location: 0.6),
                                    .init(color: .white.opacity(0.14), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    )
                    .frame(width: size, height: size)
            }

            if showsGlyph {
                Image("record-wave")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.36, height: size * 0.31)
            }
        }
    }
}

/// The huge blurred glass slab that rises from the bottom of the
/// "Record a melody" screen (Figma node 19:237).
struct LiquidGlassBlob: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 100, style: .continuous)
            .fill(Color.white.opacity(0.9))
            .frame(width: 638, height: 617)
            .blur(radius: 62)
    }
}

struct RecordingHaloView: View {
    var energy: Double
    var opacity: Double = 0.84

    @State private var lastEnergy: Double = 0
    @State private var beatDate: Date?

    var body: some View {
        let gradient = Gradient(stops: [
            .init(color: Color.white.opacity(0.64), location: 0),
            .init(color: Color.white.opacity(0.28), location: 0.34),
            .init(color: Color.white.opacity(0.08), location: 0.68),
            .init(color: .clear, location: 1)
        ])
        let clampedEnergy = min(max(energy, 0), 1)

        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let beatPunch = beatPunch(at: timeline.date)
            let livingPulse = 1 + sin(time * 1.85) * 0.055
            let baseScale = livingPulse + clampedEnergy * 0.24 + beatPunch * 0.12

            Canvas(opaque: false, colorMode: .linear) { context, size in
                let side = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = side * 0.34 * baseScale

                var glow = context
                glow.blendMode = .plusLighter
                glow.addFilter(.blur(radius: side * 0.055))

                for index in 0..<5 {
                    let layer = Double(index)
                    let phase = time * (0.76 + layer * 0.17) + layer * 1.7
                    let secondaryPhase = time * (1.08 + layer * 0.13) + layer * 0.9
                    let drift = side * (0.018 + clampedEnergy * 0.028 + beatPunch * 0.01)
                    let x = center.x + cos(phase) * drift + sin(secondaryPhase * 0.7) * drift * 0.34
                    let y = center.y + sin(phase * 1.23) * drift * 0.72 + cos(secondaryPhase) * drift * 0.24
                    let layerScale = 1 + sin(phase * 1.4) * 0.08 + clampedEnergy * 0.16 + beatPunch * 0.12
                    let layerRadius = radius * (1 - layer * 0.075) * layerScale
                    let alpha = opacity * (0.18 - layer * 0.018 + clampedEnergy * 0.045 + beatPunch * 0.02)
                    let rect = CGRect(
                        x: x - layerRadius,
                        y: y - layerRadius,
                        width: layerRadius * 2,
                        height: layerRadius * 2
                    )
                    let shading = GraphicsContext.Shading.radialGradient(
                        gradient,
                        center: CGPoint(x: rect.midX, y: rect.midY),
                        startRadius: 0,
                        endRadius: layerRadius
                    )

                    glow.opacity = alpha
                    glow.fill(Path(ellipseIn: rect), with: shading)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: energy) { _, newValue in
            let clampedNew = min(max(newValue, 0), 1)
            if clampedNew - lastEnergy > 0.16 {
                beatDate = .now
            }
            lastEnergy = clampedNew
        }
    }

    private func beatPunch(at date: Date) -> Double {
        guard let beatDate else { return 0 }
        let elapsed = date.timeIntervalSince(beatDate)
        guard elapsed < 0.42 else { return 0 }
        return max(0, exp(-elapsed * 7.4) * (1 - elapsed / 0.42))
    }
}

#Preview {
    ZStack {
        HumTheme.charcoal.ignoresSafeArea()
        VStack(spacing: 80) {
            DarkGlassCircle(size: 137)
        }
    }
}
