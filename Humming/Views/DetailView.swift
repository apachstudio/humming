import SwiftUI

struct DetailView: View {
    @Environment(AppModel.self) private var model
    let hum: Hum
    @State private var midiURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(hum.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Recorded \(Titles.recordedAt(hum.createdAt)) · \(Titles.duration(hum.durationMs)) sec")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Detected chord progression")
                        .font(.caption)
                        .textCase(.uppercase)
                        .tracking(1.6)
                        .foregroundStyle(.tertiary)
                    ChordGrid(chords: hum.chords)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Full chord timeline")
                        .font(.caption)
                        .textCase(.uppercase)
                        .tracking(1.6)
                        .foregroundStyle(.tertiary)
                    ForEach(Array(hum.chords.enumerated()), id: \.offset) { _, chord in
                        HStack {
                            Text(Titles.duration(chord.startMs))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(chord.symbol)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 8)
                    }
                }

                VStack(spacing: 10) {
                    Button("Play", systemImage: "play.fill") {
                        model.play(hum)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    if let midiURL {
                        ShareLink(item: midiURL, preview: SharePreview(hum.title, image: Image(systemName: "music.note"))) {
                            Label("Export MIDI", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Button("Delete hum", systemImage: "trash", role: .destructive) {
                        model.delete(id: hum.id)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Melody Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            midiURL = try? MIDIExport.fileURL(for: hum)
        }
        .onDisappear {
            model.stopPlayback()
        }
    }
}
