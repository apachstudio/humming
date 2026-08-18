import Foundation

/// Lean JSON-backed library of saved hums. Audio recordings are copied
/// into Documents/Audio when a hum is saved and removed when deleted.
@MainActor
final class HumStore: ObservableObject {
    @Published private(set) var hums: [Hum] = []

    private let fileManager = FileManager.default

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var indexURL: URL { documentsURL.appendingPathComponent("hums.json") }
    var audioDirectory: URL { documentsURL.appendingPathComponent("Audio", isDirectory: true) }

    init() {
        load()
    }

    func audioURL(for hum: Hum) -> URL {
        audioDirectory.appendingPathComponent(hum.audioFileName)
    }

    /// Saves a new hum, copying its recording from `audioSourceURL`
    /// (typically a temporary file) into the store.
    func add(_ hum: Hum, audioSourceURL: URL) {
        var stored = hum
        do {
            try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
            let destination = audioDirectory.appendingPathComponent("\(hum.id.uuidString).m4a")
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: audioSourceURL, to: destination)
            stored.audioFileName = destination.lastPathComponent
        } catch {
            // Keep the hum even if the audio copy failed; playback will be unavailable.
            stored.audioFileName = ""
        }
        hums.insert(stored, at: 0)
        persist()
    }

    func rename(_ hum: Hum, to newName: String) {
        guard let index = hums.firstIndex(where: { $0.id == hum.id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hums[index].name = trimmed
        persist()
    }

    func setReaction(_ reaction: String?, for hum: Hum) {
        guard let index = hums.firstIndex(where: { $0.id == hum.id }) else { return }
        hums[index].emojiReaction = reaction
        persist()
    }

    func delete(_ hum: Hum) {
        hums.removeAll { $0.id == hum.id }
        if !hum.audioFileName.isEmpty {
            try? fileManager.removeItem(at: audioURL(for: hum))
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where hums.indices.contains(index) {
            delete(hums[index])
        }
    }

    /// Default name for a fresh hum, e.g. "Idea 3".
    var nextDefaultName: String {
        "Idea \(hums.count + 1)"
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else {
            hums = Self.demoHums
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        hums = (try? decoder.decode([Hum].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(hums) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private static var demoHums: [Hum] {
        [
            Hum(
                id: uuid("E7E6D725-9F28-4B1A-96C7-15B4C30A6521"),
                name: "Sunday Hook",
                createdAt: Date.now.addingTimeInterval(-60 * 35),
                duration: 18,
                key: "Am",
                bpm: 96,
                timeSignature: "4/4",
                chords: ["Am", "F", "C", "G", "Em", "F"],
                notes: [
                    NoteEvent(pitch: 69, start: 0.0, duration: 0.45),
                    NoteEvent(pitch: 72, start: 0.55, duration: 0.35),
                    NoteEvent(pitch: 74, start: 1.05, duration: 0.5),
                    NoteEvent(pitch: 72, start: 1.72, duration: 0.4),
                    NoteEvent(pitch: 69, start: 2.25, duration: 0.55),
                    NoteEvent(pitch: 67, start: 3.0, duration: 0.45)
                ],
                audioFileName: ""
            ),
            Hum(
                id: uuid("54B50F86-CDB8-4D09-AE5A-93D516CF4D96"),
                name: "Verse Starter",
                createdAt: Date.now.addingTimeInterval(-60 * 60 * 7),
                duration: 24,
                key: "C",
                bpm: 112,
                timeSignature: "4/4",
                chords: ["C", "G", "Am", "F", "C", "Em", "F", "G"],
                notes: [
                    NoteEvent(pitch: 60, start: 0.0, duration: 0.4),
                    NoteEvent(pitch: 64, start: 0.5, duration: 0.42),
                    NoteEvent(pitch: 67, start: 1.0, duration: 0.55),
                    NoteEvent(pitch: 69, start: 1.75, duration: 0.34),
                    NoteEvent(pitch: 67, start: 2.25, duration: 0.5),
                    NoteEvent(pitch: 64, start: 3.0, duration: 0.6)
                ],
                audioFileName: ""
            ),
            Hum(
                id: uuid("A58C273E-963B-4617-A26D-195FC3C71A61"),
                name: "Late Night Chorus",
                createdAt: Date.now.addingTimeInterval(-60 * 60 * 26),
                duration: 31,
                key: "Dm",
                bpm: 84,
                timeSignature: "4/4",
                chords: ["Dm", "A#", "F", "C", "Dm", "Gm", "A#", "C"],
                notes: [
                    NoteEvent(pitch: 65, start: 0.0, duration: 0.58),
                    NoteEvent(pitch: 67, start: 0.75, duration: 0.5),
                    NoteEvent(pitch: 69, start: 1.45, duration: 0.62),
                    NoteEvent(pitch: 72, start: 2.25, duration: 0.48),
                    NoteEvent(pitch: 70, start: 2.9, duration: 0.5),
                    NoteEvent(pitch: 69, start: 3.55, duration: 0.7)
                ],
                audioFileName: ""
            )
        ]
    }

    private static func uuid(_ value: String) -> UUID {
        UUID(uuidString: value) ?? UUID()
    }
}
