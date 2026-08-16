import SwiftUI

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
/// (strongest at the top-left), a soft white bloom, a drop shadow, and a
/// centred glyph (wave on Home, stop while recording).
struct DarkGlassCircle: View {
    enum Glyph {
        case wave
        case stop
    }

    var size: CGFloat
    var showsGlyph: Bool = true
    var glyph: Glyph = .wave
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
                switch glyph {
                case .wave:
                    Image("record-wave")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.36, height: size * 0.31)
                case .stop:
                    Image(systemName: "stop.fill")
                        .font(.system(size: size * 0.2, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
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

#Preview {
    ZStack {
        HumTheme.charcoal.ignoresSafeArea()
        VStack(spacing: 80) {
            DarkGlassCircle(size: 137)
        }
    }
}
