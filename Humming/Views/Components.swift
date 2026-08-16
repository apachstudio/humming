import SwiftUI

struct WaveformBars: View {
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Capsule().frame(width: 4, height: 10)
            Capsule().frame(width: 4, height: 18)
            Capsule().frame(width: 4, height: 26)
            Capsule().frame(width: 4, height: 14)
        }
        .foregroundStyle(.primary)
        .accessibilityHidden(true)
    }
}

struct HumButton: View {
    var action: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Button(action: action) {
                WaveformBars()
                    .frame(width: 128, height: 128)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .shadow(color: .white.opacity(0.35), radius: 28)

            Text("TAP TO HUM")
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(2.6)
                .foregroundStyle(.secondary)
        }
    }
}

struct LiveWaveform: View {
    var levels: [CGFloat]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(.primary)
                    .frame(width: 4, height: max(4, 84 * level))
            }
        }
        .frame(height: 92)
        .accessibilityHidden(true)
    }
}

struct ChordGrid: View {
    var chords: [ChordEvent]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 8)], spacing: 8) {
            ForEach(Array(chords.enumerated()), id: \.offset) { _, chord in
                VStack(spacing: 4) {
                    Text(chord.symbol)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(chord.qualityLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}
