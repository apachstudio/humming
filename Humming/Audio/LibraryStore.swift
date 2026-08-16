import Foundation

enum LibraryStore {
    private static var url: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Humming", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("library.json")
    }

    static func load() -> [Hum] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Hum].self, from: data)) ?? []
    }

    static func save(_ hums: [Hum]) {
        guard let data = try? JSONEncoder().encode(hums) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

enum MIDIExport {
    static func fileURL(for hum: Hum) throws -> URL {
        let data = MIDIFile.build(notes: hum.notes, chords: hum.chords, tempo: hum.tempo)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(MIDIFile.fileName(for: hum.title))
        try data.write(to: url, options: .atomic)
        return url
    }
}
