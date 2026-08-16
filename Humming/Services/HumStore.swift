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
        guard let data = try? Data(contentsOf: indexURL) else { return }
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
}
