import SwiftUI

/// Renders the brand waveform glyph from the Figma SVG asset (path196).
/// Supports color tinting via template rendering.
struct WaveGlyphView: View {
    var color: Color = HumTheme.glyphInk

    var body: some View {
        Image("wave-glyph")
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(color)
            .scaledToFit()
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
