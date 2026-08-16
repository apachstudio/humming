import SwiftUI

struct ResultsView: View {
    @Environment(AppModel.self) private var model
    let hum: Hum
    @State private var midiURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("New hum detected")
                        .font(.caption)
                        .textCase(.uppercase)
                        .tracking(1.6)
                        .foregroundStyle(.tertiary)
                    Text(hum.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(Titles.duration(hum.durationMs)) · \(hum.key)")
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

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Estimated key")
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(1.6)
                            .foregroundStyle(.tertiary)
                        Text(hum.key)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tempo")
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(1.6)
                            .foregroundStyle(.tertiary)
                        Text("\(hum.tempo) BPM")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

                    Button(model.savedIDs.contains(hum.id) ? "Saved to library" : "Save to library") {
                        model.save(hum)
                    }
                    .disabled(model.savedIDs.contains(hum.id))
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Detection Complete")
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
