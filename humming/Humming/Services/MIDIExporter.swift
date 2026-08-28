import Foundation

/// Writes a Standard MIDI File (format 1) with a chord track and the
/// transcribed melody — ready to drop into GarageBand or Logic.
enum MIDIExporter {
    private static let ticksPerQuarter = 480

    /// Builds the .mid file in the temporary directory and returns its URL.
    static func export(hum: Hum) throws -> URL {
        var data = Data()

        let tracks = [
            metaTrack(bpm: hum.bpm),
            chordTrack(chords: hum.chords),
            melodyTrack(notes: hum.notes, bpm: hum.bpm)
        ]

        // Header chunk.
        data.append(contentsOf: Array("MThd".utf8))
        data.append(uint32(6))
        data.append(uint16(1))                       // format 1
        data.append(uint16(UInt16(tracks.count)))
        data.append(uint16(UInt16(ticksPerQuarter)))

        for track in tracks {
            data.append(contentsOf: Array("MTrk".utf8))
            data.append(uint32(UInt32(track.count)))
            data.append(track)
        }

        let safeName = hum.name
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined()
            .trimmingCharacters(in: .whitespaces)
        let fileName = (safeName.isEmpty ? "Hum" : safeName) + ".mid"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Tracks

    private static func metaTrack(bpm: Int) -> Data {
        var track = Data()
        // Tempo.
        let microsecondsPerQuarter = UInt32(60_000_000 / max(1, bpm))
        track.append(contentsOf: variableLength(0))
        track.append(contentsOf: [0xFF, 0x51, 0x03])
        track.append(UInt8((microsecondsPerQuarter >> 16) & 0xFF))
        track.append(UInt8((microsecondsPerQuarter >> 8) & 0xFF))
        track.append(UInt8(microsecondsPerQuarter & 0xFF))
        // 4/4 time signature.
        track.append(contentsOf: variableLength(0))
        track.append(contentsOf: [0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08])
        track.append(contentsOf: endOfTrack())
        return track
    }

    private static func chordTrack(chords: [String]) -> Data {
        var track = Data()
        track.append(trackName("Chords"))
        let barTicks = ticksPerQuarter * 4

        var delta = 0
        for chord in chords {
            let pitches = chordPitches(for: chord)
            guard !pitches.isEmpty else {
                delta += barTicks
                continue
            }
            for (index, pitch) in pitches.enumerated() {
                track.append(contentsOf: variableLength(index == 0 ? delta : 0))
                track.append(contentsOf: [0x90, UInt8(pitch), 72])
            }
            for (index, pitch) in pitches.enumerated() {
                track.append(contentsOf: variableLength(index == 0 ? barTicks : 0))
                track.append(contentsOf: [0x80, UInt8(pitch), 0])
            }
            delta = 0
        }
        track.append(contentsOf: endOfTrack())
        return track
    }

    private static func melodyTrack(notes: [NoteEvent], bpm: Int) -> Data {
        var track = Data()
        track.append(trackName("Melody"))
        let ticksPerSecond = Double(ticksPerQuarter) * Double(bpm) / 60.0

        var cursor = 0
        for note in notes.sorted(by: { $0.start < $1.start }) {
            let startTicks = Int(note.start * ticksPerSecond)
            let durationTicks = max(24, Int(note.duration * ticksPerSecond))
            let pitch = UInt8(min(127, max(0, note.pitch)))

            track.append(contentsOf: variableLength(max(0, startTicks - cursor)))
            track.append(contentsOf: [0x90, pitch, 96])
            track.append(contentsOf: variableLength(durationTicks))
            track.append(contentsOf: [0x80, pitch, 0])
            cursor = max(cursor, startTicks) + durationTicks
        }
        track.append(contentsOf: endOfTrack())
        return track
    }

    // MARK: - Chord symbol parsing

    /// "Am" → [57, 60, 64]; "F" → [53, 57, 60] (roots around octave 3).
    private static func chordPitches(for symbol: String) -> [Int] {
        var root: Int?
        var remainder = symbol
        if symbol.count >= 2 {
            let prefix = String(symbol.prefix(2))
            if let index = ChordEngine.noteNames.firstIndex(of: prefix) {
                root = index
                remainder = String(symbol.dropFirst(2))
            }
        }
        if root == nil, let first = symbol.first,
           let index = ChordEngine.noteNames.firstIndex(of: String(first)) {
            root = index
            remainder = String(symbol.dropFirst(1))
        }
        guard let rootClass = root else { return [] }
        let isMinor = remainder.hasPrefix("m")

        let rootNote = 48 + rootClass
        return [rootNote, rootNote + (isMinor ? 3 : 4), rootNote + 7]
    }

    // MARK: - Encoding helpers

    private static func trackName(_ name: String) -> Data {
        var data = Data()
        let bytes = Array(name.utf8)
        data.append(contentsOf: variableLength(0))
        data.append(contentsOf: [0xFF, 0x03, UInt8(bytes.count)])
        data.append(contentsOf: bytes)
        return data
    }

    private static func endOfTrack() -> [UInt8] {
        [0x00, 0xFF, 0x2F, 0x00]
    }

    private static func variableLength(_ value: Int) -> [UInt8] {
        var value = UInt32(max(0, value))
        var buffer = value & 0x7F
        while value >= 0x80 {
            value >>= 7
            buffer <<= 8
            buffer |= ((value & 0x7F) | 0x80)
        }
        var bytes: [UInt8] = []
        while true {
            bytes.append(UInt8(buffer & 0xFF))
            if buffer & 0x80 != 0 {
                buffer >>= 8
            } else {
                break
            }
        }
        return bytes
    }

    private static func uint32(_ value: UInt32) -> Data {
        Data([
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ])
    }

    private static func uint16(_ value: UInt16) -> Data {
        Data([UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)])
    }
}
