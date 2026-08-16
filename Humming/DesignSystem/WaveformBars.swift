import SwiftUI

/// Live coral waveform bars shown while listening (Figma node 5:162).
struct WaveformBars: View {
    var levels: [CGFloat]
    var maxHeight: CGFloat = 48
    var barWidth: CGFloat = 4
    var spacing: CGFloat = 4
    var color: Color = HumTheme.coral

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                Capsule(style: .continuous)
                    .fill(color.opacity(opacity(at: index)))
                    .frame(width: barWidth, height: max(6, level * maxHeight))
            }
        }
        .frame(height: maxHeight + 16)
        .animation(.linear(duration: 0.08), value: levels)
    }

    /// Older bars fade out toward the left, matching the design.
    private func opacity(at index: Int) -> Double {
        guard levels.count > 1 else { return 1 }
        return 0.5 + 0.5 * Double(index) / Double(levels.count - 1)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        WaveformBars(levels: (0..<26).map { _ in CGFloat.random(in: 0.15...1) })
    }
}
