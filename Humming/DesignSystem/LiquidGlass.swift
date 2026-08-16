import SwiftUI

/// The circular "liquid glass" button from the Figma design system:
/// a glowing white orb with soft halo and the brand wave glyph inside.
struct LiquidGlassCircle: View {
    var size: CGFloat
    var showsGlyph: Bool = true

    var body: some View {
        ZStack {
            // Soft halo bleeding into the dark background.
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: size * 1.3, height: size * 1.3)
                .blur(radius: size * 0.27)

            // Glass body.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, Color(hex: 0xB8B8B8)],
                        center: UnitPoint(x: 0.42, y: 0.4),
                        startRadius: 0,
                        endRadius: size * 0.68
                    )
                )
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.95), Color.white.opacity(0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color.white.opacity(0.28), radius: size * 0.25)

            if showsGlyph {
                WaveGlyphView()
                    .frame(width: size * 0.46, height: size * 0.39)
                    .offset(y: size * 0.02)
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
            LiquidGlassCircle(size: 137)
        }
    }
}
