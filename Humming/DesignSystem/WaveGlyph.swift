import SwiftUI

/// The Humming brand waveform glyph — a hand-drawn style scribble wave.
/// Recreated as a vector shape from the Figma logo (`path196`).
struct WaveGlyph: Shape {
    /// Normalized peak amplitudes, alternating above/below the midline.
    private static let amplitudes: [CGFloat] = [
        0.22, 0.58, 0.38, 1.0, 0.52, 0.86, 0.68, 0.95, 0.48, 0.74, 0.34, 0.55, 0.2
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let amps = Self.amplitudes
        guard amps.count > 1, rect.width > 0, rect.height > 0 else { return path }

        let midY = rect.midY
        let halfHeight = rect.height / 2
        let stepX = rect.width / CGFloat(amps.count - 1)

        for (index, amp) in amps.enumerated() {
            let x = rect.minX + CGFloat(index) * stepX
            let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let y = midY + direction * amp * halfHeight
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

/// Convenience view rendering the glyph with brand stroke styling.
struct WaveGlyphView: View {
    var color: Color = HumTheme.glyphInk
    var lineWidthRatio: CGFloat = 0.09

    var body: some View {
        GeometryReader { proxy in
            WaveGlyph()
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: max(1.5, proxy.size.height * lineWidthRatio),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .padding(proxy.size.height * 0.08)
        }
    }
}

#Preview {
    ZStack {
        HumTheme.charcoal
        WaveGlyphView(color: .white)
            .frame(width: 120, height: 60)
    }
    .ignoresSafeArea()
}
