import SwiftUI

struct LibraryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.library.isEmpty {
                ContentUnavailableView(
                    "Nothing here yet.",
                    systemImage: "waveform",
                    description: Text("Hum a melody and save it — it will live in this library.")
                )
            } else {
                List {
                    ForEach(model.library) { hum in
                        NavigationLink(value: Route.detail(hum.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(hum.title)
                                    .font(.headline)
                                Text(subtitle(for: hum))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                model.delete(id: hum.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            model.delete(id: model.library[index].id)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Your Hums")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func subtitle(for hum: Hum) -> String {
        let chords = hum.chords.map(\.symbol).joined(separator: " ")
        return "\(Titles.recordedAt(hum.createdAt)) · \(Titles.duration(hum.durationMs))"
            + (chords.isEmpty ? "" : " · \(chords)")
    }
}
